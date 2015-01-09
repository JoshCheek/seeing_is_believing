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
require 'seeing_is_believing/event_stream/update_result'

class SeeingIsBelieving
  class EvaluateByMovingFiles
    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :filename, :provided_input, :require_flags, :load_path_flags, :encoding, :timeout, :debugger

    # TODO: blow up if given unknown args
    def initialize(program, filename, options={})
      self.program         = program
      self.filename        = filename
      self.provided_input  = options.fetch :provided_input, String.new
      self.require_flags   = options.fetch(:require, ['seeing_is_believing/the_matrix']).map { |filename| ['-r', filename] }.flatten
      self.load_path_flags = options.fetch(:load_path, []).map { |dir| ['-I', dir] }.flatten
      self.encoding        = options.fetch :encoding, nil
      self.timeout         = options.fetch :timeout, 0 # default: none
      self.debugger        = options.fetch :debugger, Debugger.new(stream: nil)
    end

    def call
      @result ||= HardCoreEnsure.call \
        code: -> {
          we_will_not_overwrite_existing_tempfile!
          move_file_to_tempfile
          write_program_to_file
          result = Result.new
          begin  evaluate_file { |event| EventStream::UpdateResult.call result, event }
          rescue Timeout::Error; raise
          rescue Exception;      raise wrap_error result, $! # <-- do we know what kinds of errors can come up? would it be better blacklist?
          end
          result
        },
        ensure: -> {
          set_back_to_initial_conditions
        }
    end

    def file_directory
      File.dirname filename
    end

    def temp_filename
      File.join file_directory, "seeing_is_believing_backup.#{File.basename filename}"
    end

    private

    def we_will_not_overwrite_existing_tempfile!
      raise TempFileAlreadyExists.new(filename, temp_filename) if File.exist? temp_filename
    end

    def move_file_to_tempfile
      return unless File.exist? filename
      File.rename filename, temp_filename
      @was_backed_up = true
    end

    def set_back_to_initial_conditions
      @was_backed_up ?
        File.rename(temp_filename, filename) :
        File.delete(filename)
    end

    def write_program_to_file
      File.open(filename, 'w') { |f| f.write program.to_s }
    end

    # have to basically copy a bunch of Open3 code into here b/c keywords don't work right when the keys are not symbols
    # https://github.com/ruby/ruby/pull/808    my PR
    # https://bugs.ruby-lang.org/issues/10699  they opened an issue
    # https://bugs.ruby-lang.org/issues/10118  weird feature vs bug conversation
    def evaluate_file(&event_handler)
      # setup streams
      eventstream, child_eventstream = IO.pipe
      stdout,      child_stdout      = IO.pipe
      stderr,      child_stderr      = IO.pipe
      child_stdin, stdin             = IO.pipe

      # evaluate the code in a child process
      args  = [ENV, *popen_args, child_eventstream.to_i.to_s]
      opts  = {in: child_stdin, out: child_stdout, err: child_stderr, child_eventstream => child_eventstream}
      child = Process.detach spawn(*args, opts)

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
      Timeout.timeout timeout do
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

    def wrap_error(result, error)
      debugger.context "Program could not be evaluated" do
        "Program:      #{program.inspect.chomp}\n\n"\
        "Stderr:       #{result.stderr.inspect.chomp}\n\n"\
        "Status:       #{result.exitstatus.inspect.chomp}\n\n"\
        "Result:       #{result.inspect.chomp}\n\n"\
        "Actual Error: #{error.inspect.chomp}\n"+
        error.backtrace.map { |sf| "              #{sf}\n" }.join("")
      end
      BugInSib.new error
    end
  end
end
