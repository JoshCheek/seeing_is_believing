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

require 'timeout'
require 'seeing_is_believing/error'
require 'seeing_is_believing/result'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/hard_core_ensure'
require 'seeing_is_believing/event_stream/consumer'

class SeeingIsBelieving
  class EvaluateByMovingFiles
    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :filename, :provided_input, :require_flags, :load_path_flags, :encoding, :timeout_seconds, :debugger, :event_handler

    def initialize(program, filename,  options={})
      options = options.dup
      self.program         = program
      self.filename        = filename
      self.encoding        = options.delete(:encoding)
      self.timeout_seconds = options.delete(:timeout_seconds) || 0 # 0 is the new infinity
      self.provided_input  = options.delete(:provided_input)  || String.new
      self.event_handler   = options.delete(:event_handler)   || raise("must provide an event handler")
      self.load_path_flags = (options.delete(:load_path_dirs) || []).map { |dir| ['-I', dir] }.flatten
      self.require_flags   = (options.delete(:require_files)  || ['seeing_is_believing/the_matrix']).map { |filename| ['-r', filename] }.flatten
      options.any? && raise(ArgumentError, "Unknown options: #{options.inspect}")
    end

    def call
      HardCoreEnsure.call \
        code: -> {
          we_will_not_overwrite_existing_backup_file!
          backup_existing_file
          write_program_to_file
          evaluate_file
        },
        ensure: -> {
          set_back_to_initial_conditions
        }
    end

    def file_directory
      File.dirname filename
    end

    def backup_filename
      File.join file_directory, "seeing_is_believing_backup.#{File.basename filename}"
    end

    private

    def we_will_not_overwrite_existing_backup_file!
      raise TempFileAlreadyExists.new(filename, backup_filename) if File.exist? backup_filename
    end

    def backup_existing_file
      return unless File.exist? filename
      File.rename filename, backup_filename
      @was_backed_up = true
    end

    def set_back_to_initial_conditions
      @was_backed_up ?
        File.rename(backup_filename, filename) :
        File.delete(filename)
    end

    def write_program_to_file
      File.open(filename, 'w') { |f| f.write program.to_s }
    end

    # have to basically copy a bunch of Open3 code into here b/c keywords don't work right when the keys are not symbols
    # https://github.com/ruby/ruby/pull/808    my PR
    # https://bugs.ruby-lang.org/issues/10699  they opened an issue
    # https://bugs.ruby-lang.org/issues/10118  weird feature vs bug conversation
    def evaluate_file
      # setup streams
      eventstream, child_eventstream = IO.pipe
      stdout,      child_stdout      = IO.pipe
      stderr,      child_stderr      = IO.pipe
      child_stdin, stdin             = IO.pipe

      # evaluate the code in a child process
      env   = ENV.to_hash.merge('SIB_EVENT_STREAM_FD' => child_eventstream.to_i.to_s)
      opts  = {in: child_stdin, out: child_stdout, err: child_stderr, child_eventstream => child_eventstream}
      child = Process.detach spawn(env, *popen_args, opts)

      # close b/c we won't get EOF until all fds are closed
      child_eventstream.close
      child_stdout.close
      child_stderr.close
      child_stdin.close
      stdin.sync = true

      # send stdin
      Thread.new {
        provided_input.each_char { |char| stdin.write char }
        stdin.close
      }

      # consume events
      consumer        = EventStream::Consumer.new(events: eventstream, stdout: stdout, stderr: stderr)
      consumer_thread = Thread.new { consumer.each &event_handler }

      # wait for completion
      Timeout.timeout timeout_seconds do
        exitstatus = child.value.exitstatus
        consumer.process_exitstatus exitstatus
        consumer_thread.join
      end
    rescue Timeout::Error
      Process.kill "TERM", child.pid
      raise
    ensure
      [stdin, stdout, stderr, eventstream].each { |io| io.close unless io.closed? }
    end

    def popen_args
      [RbConfig.ruby,
         '-W0',                                     # no warnings (b/c I hijack STDOUT/STDERR)
         *(encoding ? ["-K#{encoding}"] : []),      # allow the encoding to be set
         '-I', File.expand_path('../..', __FILE__), # add lib to the load path
         *load_path_flags,                          # users can inject dirs to be added to the load path
         *require_flags,                            # users can inject files to be required
         filename]
    end
  end
end
