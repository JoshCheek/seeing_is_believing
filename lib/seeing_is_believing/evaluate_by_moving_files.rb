# Not sure what the best way to evaluate these is
# This approach will move the old file out of the way,
# write the program in its place, invoke it, and move it back.
#
# Another option is to replace __FILE__ macros ourselves
# and then write to a temp file but evaluate in the context
# of the expected directory. I'm not doing that just because
# I don't think the __FILE__ macro can be replaced correctly
# without parsing the code, changing the AST, and then
# regenerating it, which I'm not good enough to do. Though
# I did look at Ripper, and it will invoke on_kw("__FILE__")
# when it sees this.

require 'open3'
require 'stringio'
require 'fileutils'
require 'seeing_is_believing/error'
require 'seeing_is_believing/result'
require 'seeing_is_believing/hard_core_ensure'

class SeeingIsBelieving
  class EvaluateByMovingFiles
    attr_accessor :program, :filename, :error_stream, :input_stream

    def initialize(program, filename, options={})
      self.program      = program
      self.filename     = File.expand_path(filename)
      self.error_stream = options.fetch :error_stream, $stderr # hmm, not really liking the global here
      self.input_stream = options.fetch :input_stream, StringIO.new('')
    end

    def call
      @result ||= HardCoreEnsure.call(
        code: -> {
          dont_overwrite_existing_tempfile!
          move_file_to_tempfile
          write_program_to_file
          begin
            evaluate_file
            fail unless exitstatus.success?
            deserialize_result
          rescue Exception
            record_error
            raise $!
          end
        },
        ensure: -> {
          restore_backup
        }
      )
    end

    def file_directory
      File.dirname filename
    end

    def temp_filename
      File.join file_directory, "seeing_is_believing_backup.#{File.basename filename}"
    end

    private

    attr_accessor :stdout, :stderr, :exitstatus

    def dont_overwrite_existing_tempfile!
      raise TempFileAlreadyExists.new(filename, temp_filename) if File.exist? temp_filename
    end

    def move_file_to_tempfile
      return unless File.exist? filename
      FileUtils.mv filename, temp_filename
      @was_backed_up = true
    end

    def restore_backup
      return unless @was_backed_up
      FileUtils.mv temp_filename, filename
    end

    def write_program_to_file
      File.open(filename, 'w') { |f| f.write program.to_s }
    end

    def evaluate_file
      Open3.popen3 'ruby', '-W0',                                     # no warnings (b/c I hijack STDOUT/STDERR)
                           '-I', File.expand_path('../..', __FILE__), # fix load path
                           '-r', 'seeing_is_believing/the_matrix',    # hijack the environment so it can be recorded
                           '-C', file_directory,                      # run in the file's directory
                           filename do |i, o, e, t|
        out_reader = Thread.new { o.read }
        err_reader = Thread.new { e.read }
        Thread.new do
          input_stream.each_char { |char| i.write char }
          i.close
        end
        self.stdout     = out_reader.value
        self.stderr     = err_reader.value
        self.exitstatus = t.value
      end
    end

    def fail
      raise "Exitstatus: #{exitstatus.inspect},\nError: #{stderr.inspect}"
    end

    def deserialize_result
      Marshal.load stdout
    end

    def record_error
      error_stream.puts "It blew up. Not too surprising given that seeing_is_believing is pretty rough around the edges, but still this shouldn't happen."
      error_stream.puts "Please log an issue at: https://github.com/JoshCheek/seeing_is_believing/issues"
      error_stream.puts
      error_stream.puts "Program: #{program.inspect}"
      error_stream.puts
      error_stream.puts "Stdout: #{stdout.inspect}"
      error_stream.puts
      error_stream.puts "Stderr: #{stderr.inspect}"
      error_stream.puts
      error_stream.puts "Status: #{exitstatus.inspect}"
    end
  end
end
