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

require 'json'
require 'open3'
require 'timeout'
require 'stringio'
require 'fileutils'
require 'seeing_is_believing/error'
require 'seeing_is_believing/result'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/hard_core_ensure'

class SeeingIsBelieving
  class EvaluateByMovingFiles

    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :filename, :input_stream, :matrix_filename, :require_flags, :load_path_flags, :encoding, :timeout, :ruby_executable, :debugger

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
            deserialize_result.tap { |result| fail if result.bug_in_sib? }
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
        out_reader = Thread.new { process_stdout.read }
        err_reader = Thread.new { process_stderr.read }
        Thread.new do
          input_stream.each_char { |char| process_stdin.write char }
          process_stdin.close
        end
        begin
          Timeout::timeout timeout do
            self.stdout     = out_reader.value
            self.stderr     = err_reader.value
            self.exitstatus = thread.value
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

    def deserialize_result
      Result.from_primitive JSON.load stdout
    end

    def wrap_error(error)
      debugger.context "Program could not be evaluated" do
        "Program: #{program.inspect.chomp}\n\n"\
        "Stdout: #{stdout.inspect.chomp}\n\n"\
        "Stderr: #{stderr.inspect.chomp}\n\n"\
        "Status: #{exitstatus.inspect.chomp}\n"
      end
      BugInSib.new error
    end
  end
end
