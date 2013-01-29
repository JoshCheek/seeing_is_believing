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

    def exitstatus
      call
      @exitstatus
    end

    def call
      return if @already_called
      @already_called = true

      program_status = 0

      argv.each do |filename|
        out, err, syntax_status = Open3.capture3('ruby', '-c', filename)
        unless syntax_status.success?
          program_status = 1
          stderr.puts err
          next
        end
        believer = SeeingIsBelieving::PrintResultsNextToLines.new File.read(filename), filename
        stdout.puts believer.call
        if believer.has_exception?
          stderr.puts believer.exception.message
          program_status = 1
        end
      end

      @exitstatus = program_status
    end
  end
end
