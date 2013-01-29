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

      @exitstatus = 0

      filename = argv.first
      out, err, syntax_status = Open3.capture3('ruby', '-c', filename)
      if syntax_status.success?
        believer = SeeingIsBelieving::PrintResultsNextToLines.new File.read(filename), filename
        stdout.puts believer.call
        if believer.has_exception?
          stderr.puts believer.exception.message
          @exitstatus = 1
        end
      else
        @exitstatus = 1
        stderr.puts err
      end
    end

    def exitstatus
      call
      @exitstatus
    end
  end
end
