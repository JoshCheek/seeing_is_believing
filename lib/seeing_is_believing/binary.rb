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

    def call
      return if @already_called
      @already_called = true

      file_exists_or_is_on_stdin &&
        syntax_is_valid          &&
        print_program            &&
        display_exceptions
    end

    def exitstatus
      call
      @exitstatus
    end

    private

    def on_stdin?
      argv.empty?
    end

    def filename
      argv.first
    end

    def believer
      @believer ||= begin
        if on_stdin?
          PrintResultsNextToLines.new stdin.read, ''
        else
          PrintResultsNextToLines.new File.read(filename), stdin, filename
        end
      end
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

    def print_program
      stdout.puts believer.call
      true
    end

    def display_exceptions
      if believer.has_exception?
        stderr.puts believer.exception.message
        @exitstatus = 1
      else
        @exitstatus = 0
      end
    end
  end
end
