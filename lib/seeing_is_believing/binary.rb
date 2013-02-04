require 'seeing_is_believing/arg_parser'
require 'seeing_is_believing/print_results_next_to_lines'

class SeeingIsBelieving
  class Binary
    attr_accessor :argv, :stdin, :stdout, :stderr

    def initialize(argv, stdin, stdout, stderr)
      self.argv   = argv
      self.stdin  = stdin
      self.stdout = stdout
      self.stderr = stderr
    end

    # used to like this, but now it's ick,
    # the command/query violation is confusing
    def call
      return if @already_called
      @already_called = true

      flags_are_valid && (
        print_help || (
          file_exists_or_is_on_stdin  &&
          syntax_is_valid             &&
          print_program               &&
          has_no_exceptions))
    end

    def exitstatus
      call
      @exitstatus
    end

    private

    def on_stdin?
      filename.nil?
    end

    def filename
      flags[:filename]
    end

    # rename this, it's no longer accurate
    # refactor this shiz
    def believer
      @believer ||= begin
        if on_stdin?
          body  = stdin.read
          stdin = ''
        else
          body  = File.read(filename)
          stdin = stdin()
        end
        PrintResultsNextToLines.new body,
                                    stdin,
                                    filename:   filename,
                                    start_line: flags[:start_line],
                                    end_line:   flags[:end_line]
      end
    end

    def flags
      @flags ||= ArgParser.parse argv
    end

    def flags_are_valid
      return true if flags[:errors].empty?
      @exitstatus = 1
      flags[:errors].each { |error| stderr.puts error }
      false
    end

    def file_exists_or_is_on_stdin
      return true if on_stdin? || File.exist?(filename)
      @exitstatus = 1
      stderr.puts "#{filename} does not exist!"
      false
    end

    def syntax_is_valid
      return true if on_stdin? # <-- should probably check stdin too
      out, err, syntax_status = Open3.capture3('ruby', '-c', filename)
      return true if syntax_status.success?
      @exitstatus = 1
      stderr.puts err
      false
    end

    def print_help
      return unless flags[:help]
      stdout.puts flags[:help]
      @exitstatus = 0
      true
    end

    def print_program
      stdout.puts believer.call
      true
    end

    def has_no_exceptions
      @exitstatus = (believer.has_exception? ? 1 : 0)
    end
  end
end
