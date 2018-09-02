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
require "childprocess"

require 'seeing_is_believing/result'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/backup_file'
require 'seeing_is_believing/event_stream/consumer'

ChildProcess.posix_spawn = true # forking locks up for some reason when we run SiB inside of SiB

class SeeingIsBelieving
  class EvaluateByMovingFiles
    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :provided_input, :require_flags, :load_path_flags, :encoding, :timeout_seconds, :debugger, :event_handler, :max_line_captures

    attr_accessor :file_directory, :file_path, :local_cwd, :relative_filename, :backup_filename

    def initialize(program, file_path,  options={})
      options = options.dup
      self.program           = program
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
      self.backup_filename   = File.join file_directory, "seeing_is_believing_backup.#{file_name}"

      options.any? && raise(ArgumentError, "Unknown options: #{options.inspect}")
    end

    def call
      BackupFile.call file_path, backup_filename do
        write_program_to_file
        evaluate_file
      end
    end

    private

    def write_program_to_file
      File.open(file_path, 'w', external_encoding: "utf-8") { |f| f.write program.to_s }
    end


    def evaluate_file
      event_server = TCPServer.new(0) # dynamically allocates an available port

      # setup streams
      stdout, child_stdout = IO.pipe("utf-8")
      stderr, child_stderr = IO.pipe("utf-8")

      # setup environment variables
      env = ENV.to_hash.merge 'SIB_VARIABLES.MARSHAL.B64' =>
                                [Marshal.dump(
                                  event_stream_port: event_server.addr[1],
                                  max_line_captures: max_line_captures,
                                  num_lines:         program.lines.count,
                                  filename:          relative_filename,
                                )].pack('m0')

      child = ChildProcess.build(*popen_args)
      child.cwd    = file_directory if local_cwd
      child.leader = true
      child.duplex = true
      child.environment.merge!(env)
      child.io.stdout = child_stdout
      child.io.stderr = child_stderr

      child.start

      # close child streams b/c they won't emit EOF if parent still has an open reference
      close_streams(child_stdout, child_stderr)
      child.io.stdin.binmode
      child.io.stdin.sync = true

      # Start receiving events from the child
      eventstream = event_server.accept

      # send stdin (char at a time b/c input could come from a stream)
      Thread.new do
        begin
          provided_input.each_char { |char| child.io.stdin.write char }
        rescue
          # don't explode if child closes IO
        ensure
          child.io.stdin.close
        end
      end

      # set up the event consumer
      consumer = EventStream::Consumer.new(events: eventstream, stdout: stdout, stderr: stderr)
      consumer_thread = Thread.new { consumer.each { |e| event_handler.call e } }

      # wait for completion
      if timeout_seconds == 0
        child.wait
      else
        child.poll_for_exit(timeout_seconds)
      end
      consumer.process_exitstatus(child.exit_code)
      consumer_thread.join
    rescue ChildProcess::TimeoutError
      consumer.process_timeout(timeout_seconds)
      child.stop
      consumer_thread.join
    ensure
      # On Windows, we need to call stop if there is an error since it interrupted
      # the previos waiting/polling. If we don't call stop, in that situation, it will
      # leave orphan processes. On Unix, we need to always call stop or it may leave orphans
      if ChildProcess.unix?
        child.stop
      elsif $!
        child.stop
        consumer.process_exitstatus(child.exit_code)
      end
      cleanup_run(child)
      close_streams(stdout, stderr, eventstream, event_server)
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

    # On AppVeyor, I keep getting errors
    #   The handle is invalid: https://ci.appveyor.com/project/JoshCheek/seeing-is-believing/build/22
    #   Access is denied:      https://ci.appveyor.com/project/JoshCheek/seeing-is-believing/build/24
    def cleanup_run(child, *streams)
      child.alive? && child.stop
    rescue ChildProcess::Error
      # noop
    end
  end
end
