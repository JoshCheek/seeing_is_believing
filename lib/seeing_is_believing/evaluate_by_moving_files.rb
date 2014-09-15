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

require 'open3'
require 'timeout'
require 'stringio'
require 'fileutils'
require 'seeing_is_believing/error'
require 'seeing_is_believing/result'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/hard_core_ensure'
require 'seeing_is_believing/event_stream'

class SeeingIsBelieving
  class EvaluateByMovingFiles

    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :filename, :input_stream, :matrix_filename, :require_flags, :load_path_flags, :encoding, :timeout, :ruby_executable, :debugger, :result

    def initialize(program, filename, options={})
      self.program         = program
      self.filename        = filename
      self.input_stream    = options.fetch :input_stream, StringIO.new('')
      self.matrix_filename = options[:matrix_filename] || 'seeing_is_believing/the_matrix'
      self.require_flags   = options.fetch(:require, []).map { |filename| ['-r', filename] }.flatten
      self.load_path_flags = options.fetch(:load_path, []).map { |dir| ['-I', dir] }.flatten
      self.encoding        = options.fetch :encoding, nil
      self.timeout         = options[:timeout]
      self.ruby_executable = options.fetch :ruby_executable, 'ruby'
      self.debugger        = options.fetch :debugger, Debugger.new(stream: nil)
    end

    def call
      @result ||= HardCoreEnsure.call \
        code: -> {
          we_will_not_overwrite_existing_tempfile!
          move_file_to_tempfile
          write_program_to_file
          begin
            evaluate_file
            fail if result.bug_in_sib?
            result
          rescue Exception => error
            error = wrap_error error if error_implies_bug_in_sib? error
            raise error
          end
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

    attr_accessor :stdout, :stderr, :exitstatus

    def error_implies_bug_in_sib?(error)
      not error.kind_of? Timeout::Error
    end

    def we_will_not_overwrite_existing_tempfile!
      raise TempFileAlreadyExists.new(filename, temp_filename) if File.exist? temp_filename
    end

    def move_file_to_tempfile
      return unless File.exist? filename
      FileUtils.mv filename, temp_filename
      @was_backed_up = true
    end

    def set_back_to_initial_conditions
      if @was_backed_up
        FileUtils.mv temp_filename, filename
      else
        FileUtils.rm filename
      end
    end

    def write_program_to_file
      File.open(filename, 'w') { |f| f.write program.to_s }
    end

    def evaluate_file
      Open3.popen3 ENV, *popen_args do |process_stdin, process_stdout, process_stderr, thread|
        # send stdin
        Thread.new {
          input_stream.each_char { |char| process_stdin.write char }
          process_stdin.close
        }

        # consume events
        self.result = Result.new
        event_consumer = Thread.new {
          EventStream::Consumer.new(process_stdout).each do |event|
            case event
            when EventStream::Event::LineResult       then result.record_result(event.type, event.line_number, event.inspected)
            when EventStream::Event::UnrecordedResult then result.record_result(event.type, event.line_number, '...') # <-- is this really what I want?
            when EventStream::Event::Stdout           then result.stdout             = event.stdout
            when EventStream::Event::Stderr           then result.stderr             = event.stderr
            when EventStream::Event::BugInSiB         then result.bug_in_sib         = event.value
            when EventStream::Event::MaxLineCaptures  then result.number_of_captures = event.value
            when EventStream::Event::Exitstatus       then result.exitstatus         = event.value
            when EventStream::Event::Exception        then result.record_exception event.line_number, event.class_name, event.message, event.backtrace
            else raise "Unknown event: #{event.inspect}"
            end
          end
        }

        # process stderr
        err_reader = Thread.new { process_stderr.read }

        begin
          Timeout::timeout timeout do
            self.stderr     = err_reader.value
            self.exitstatus = thread.value
            event_consumer.join
          end
        rescue Timeout::Error
          Process.kill "TERM", thread.pid
          raise $!
        end
      end
    end

    def popen_args
      [ruby_executable,
         '-W0',                                     # no warnings (b/c I hijack STDOUT/STDERR)
         *(encoding ? ["-K#{encoding}"] : []),      # allow the encoding to be set
         '-I', File.expand_path('../..', __FILE__), # add lib to the load path
         '-r', matrix_filename,                     # hijack the environment so it can be recorded
         *load_path_flags,                          # users can inject dirs to be added to the load path
         *require_flags,                            # users can inject files to be required
         filename]
    end

    def fail
      raise "Exitstatus: #{exitstatus.inspect},\nError: #{stderr.inspect}"
    end

    def wrap_error(error)
      debugger.context "Program could not be evaluated" do
        "Program:      #{program.inspect.chomp}\n\n"\
        "Stderr:       #{stderr.inspect.chomp}\n\n"\
        "Status:       #{exitstatus.inspect.chomp}\n\n"\
        "Result:       #{result.inspect.chomp}\n\n"\
        "Actual Error: #{error.inspect.chomp}\n"+
        error.backtrace.map { |sf| "              #{sf}\n" }.join("")
      end
      BugInSib.new error
    end
  end
end
