require 'seeing_is_believing'
require 'seeing_is_believing/has_exception'

class SeeingIsBelieving
  class ExampleUse
    include HasException

    def initialize(body)
      self.body = body.gsub(/\s+# [~=]>.*?$/, '')
    end

    def call
      result = SeeingIsBelieving.new(body).call
      self.exception = result.exception

      has_seen_stdout = false
      has_seen_stderr = false

      body.each_line.with_index 1 do |line, index|
        if is_stdout?(line)
          output.chomp! unless has_seen_stdout
          has_seen_stdout = true
          next
        end
        if is_stderr?(line)
          output.chomp! unless has_seen_stderr
          has_seen_stderr = true
          next
        end
        output << format_line(line.chomp, result[index])
      end

      if result.has_stdout?
        output << "\n"
        result.stdout.each_line { |line| output << "# >> #{line}" }
      end

      if result.has_stderr?
        output << "\n"
        result.stderr.each_line { |line| output << "# !> #{line}" }
      end

      output
    end

    def output
      @result ||= ''
    end

    private

    attr_accessor :body

    def is_stdout?(line)
      line.start_with? '# >>'
    end

    def is_stderr?(line)
      line.start_with? '# !>'
    end

    # max line length of the body + 2 spaces for padding
    def line_length
      @line_length ||= 2 + body.each_line
                               .map(&:chomp)
                               .reject { |line| SyntaxAnalyzer.ends_in_comment? line }
                               .map(&:length)
                               .max
    end

    def format_line(line, line_results)
      if line_results.has_exception?
        sprintf "%-#{line_length}s# ~> %s: %s\n", line, line_results.exception.class, line_results.exception.message
      elsif line_results.any?
        sprintf "%-#{line_length}s# => %s\n", line, line_results.join(', ')
      else
        line + "\n"
      end
    end
  end
end
