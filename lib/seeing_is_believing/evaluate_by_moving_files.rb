# Not sure what the best way to evaluate these is
# This approach will move the old file out of the way,
# write the program in its place, invoke it, and move it back.
#
# Another option is to replace __FILE__ macros ourselves
# and then write to a temp file but evaluate in the context
# of the expected directory. Some issues could arise with this,
# though: if you required the file again, it wouldn't already
# be in the loaded features (might be able to just add it)
# if you  did something like File.read(__FILE__) it would
# read the wrong file... of course, since we rewrite the file,
# its body will be incorrect, anyway.
require 'rbconfig'
require 'socket'

require 'seeing_is_believing/result'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/swap_files'
require 'seeing_is_believing/event_stream/consumer'
require 'seeing_is_believing/event_stream/events'

class SeeingIsBelieving
  class EvaluateByMovingFiles
    def self.call(*args)
      new(*args).call
    end

    attr_accessor :user_program, :rewritten_program, :provided_input, :require_flags, :load_path_flags, :encoding, :timeout_seconds, :debugger, :event_handler, :max_line_captures

    attr_accessor :file_directory, :file_path, :local_cwd, :relative_filename, :backup_path

    def initialize(file_path, user_program, rewritten_program, options={})
      options = options.dup
      self.user_program      = user_program
      self.rewritten_program = rewritten_program
      self.encoding          = options.delete(:encoding)           || "u"
      self.timeout_seconds   = options.delete(:timeout_seconds)    || 0 # 0 is the new infinity
      self.provided_input    = options.delete(:provided_input)     || String.new
      self.event_handler     = options.delete(:event_handler)      || raise(ArgumentError, "must provide an :event_handler")
      self.load_path_flags   = (options.delete(:load_path_dirs)    || []).flat_map { |dir| ['-I', dir] }
      self.require_flags     = (options.delete(:require_files)     || ['seeing_is_believing/the_matrix']).map { |filename| ['-r', filename] }.flatten
      self.max_line_captures = (options.delete(:max_line_captures) || Float::INFINITY) # (optimization: child stops producing results at this number, even though it might make more sense for the consumer to stop emitting them)
      self.local_cwd         = options.delete(:local_cwd)          || false
      self.file_path         = file_path
      self.file_directory    = File.dirname file_path
      file_name              = File.basename file_path
      self.relative_filename = local_cwd ? file_name : file_path
      self.backup_path       = File.join file_directory, "seeing_is_believing_backup.#{file_name}"

      options.any? && raise(ArgumentError, "Unknown options: #{options.inspect}")
    end

    def call
      SwapFiles.call file_path, backup_path, user_program, rewritten_program do |swap_files|
        evaluate_file swap_files
      end
    end

    private

    def evaluate_file(swap_files)
      event_server = TCPServer.new(0) # dynamically allocates an available port

      # setup streams
      child_stdin, stdin   = IO.pipe("utf-8")
      stdout, child_stdout = IO.pipe("utf-8")
      stderr, child_stderr = IO.pipe("utf-8")

      # setup environment variables
      env = ENV.to_hash.merge 'SIB_VARIABLES.MARSHAL.B64' =>
                                [Marshal.dump(
                                  event_stream_port: event_server.addr[1],
                                  max_line_captures: max_line_captures,
                                  num_lines:         user_program.lines.count,
                                  filename:          relative_filename,
                                )].pack('m0')

      opts = { in: child_stdin, out: child_stdout, err: child_stderr }
      opts[:chdir] = file_directory if local_cwd
      if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        opts[:new_pgroup] = true # windows
      else
        opts[:pgroup] = true
      end

      pid = spawn env, *popen_args, **opts
      waiting = true
      started_at = Time.now

      # child.leader = true
      # child.start

      # close child streams b/c they won't emit EOF if parent still has an open reference
      stdin.binmode
      stdin.sync = true
      close_streams(child_stdin, child_stdout, child_stderr)

      # Start receiving events from the child
      eventstream = event_server.accept

      # send stdin (char at a time b/c input could come from a stream)
      Thread.new do
        begin
          provided_input.each_char { |char| stdin.write char }
        rescue
          # don't explode if child closes IO
        ensure
          stdin.close
        end
      end

      # set up the event consumer
      consumer = EventStream::Consumer.new(events: eventstream, stdout: stdout, stderr: stderr)
      consumer_thread = Thread.new do
        consumer.each do |e|
          swap_files.show_user_program if e.is_a? SeeingIsBelieving::EventStream::Events::FileLoaded
          event_handler.call e
        end
      end

      if timeout_seconds == 0
        _pid, status = Process.waitpid2 -pid, Process::WUNTRACED
        waiting = false
        consumer.process_exitstatus(status.exitstatus)
      else
        stop_at = started_at + timeout_seconds
        loop do
          _pid, status = Process.waitpid2 -pid, Process::WUNTRACED|Process::WNOHANG
          if status
            waiting = false
            consumer.process_exitstatus(status.exitstatus)
            break
          end
          if stop_at <= Time.now
            consumer.process_timeout timeout_seconds
            Process.kill 9, -pid# rescue Errno::ESRCH
            _pid, _status = Process.wait2 -pid, Process::WUNTRACED
            waiting = false
            break
          end
          sleep 0.01
        end
      end
      consumer_thread.join

    ensure
      Process.kill 9, -pid if waiting
      close_streams(stdin, stdout, stderr, eventstream, event_server)
    end

    def popen_args
      [RbConfig.ruby,
         '-W0',                                     # no warnings (b/c I hijack STDOUT/STDERR)
         *(encoding ? ["-K#{encoding}"] : []),      # allow the encoding to be set
         '-I', File.realpath('..', __dir__),        # add lib to the load path
         *load_path_flags,                          # users can inject dirs to be added to the load path
         *require_flags,                            # users can inject files to be required
         relative_filename]
    end

    def close_streams(*streams)
      streams.each { |io| io.close unless io.closed? }
    end
  end
end
