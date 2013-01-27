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

require 'yaml'
require 'open3'
require 'fileutils'
require 'seeing_is_believing/error'
require 'seeing_is_believing/result'
require 'seeing_is_believing/hard_core_ensure'

class SeeingIsBelieving
  class EvaluateByMovingFiles
    attr_accessor :program, :filename, :error_stream

    def initialize(program, filename, options={})
      self.program      = program
      self.filename     = File.expand_path(filename)
      self.error_stream = options.fetch :error_stream, $stderr
    end

    # clean me up *ugh*
    def call
      moved = false

      HardCoreEnsure.call \
        ensure: -> { FileUtils.mv temp_filename, filename if moved },

        code: -> {
          if File.exist? temp_filename
            raise TempFileAlreadyExists,
              "Trying to back up #{filename.inspect} (FILE) to #{temp_filename.inspect} (TEMPFILE) but TEMPFILE already exists."\
              " You should check the contents of these files. If FILE is correct, then delete TEMPFILE."\
              " Otherwise rename TEMPFILE to FILE."
          end

          if File.exist? filename
            FileUtils.mv filename, temp_filename
            moved = true
          end

          File.open(filename, 'w') { |f| f.write program.to_s }

          begin
            stdout, stderr, exitstatus = Open3.capture3(
              'ruby', '-W0',                                     # no warnings (b/c I hijack STDOUT/STDERR)
                      '-I', File.expand_path('../..', __FILE__), # fix load path
                      '-r', 'seeing_is_believing/the_matrix',    # hijack the environment so it can be recorded
                      '-C', file_directory,                      # run in the file's directory
                      filename)
            raise "Exitstatus: #{exitstatus.inspect},\nError: #{stderr.inspect}" unless exitstatus.success?
            YAML.load stdout
          rescue Exception
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
            raise $!
          end
        }
    end

    def file_directory
      File.dirname filename
    end

    def temp_filename
      File.join file_directory, "seeing_is_believing_backup.#{File.basename filename}"
    end
  end
end
