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

      unless File.exist? filename
        @exitstatus = 1
        stderr.puts "#{filename} does not exist!"
        return
      end

      out, err, syntax_status = Open3.capture3('ruby', '-c', filename)
      unless syntax_status.success?
        @exitstatus = 1
        stderr.puts err
        return
      end

      believer = PrintResultsNextToLines.new File.read(filename), stdin, filename
      stdout.puts believer.call
      if believer.has_exception?
        stderr.puts believer.exception.message
        @exitstatus = 1
      else
        @exitstatus = 0
      end
    end

    def exitstatus
      call
      @exitstatus
    end

    private

    def filename
      argv.first
    end
  end
end
