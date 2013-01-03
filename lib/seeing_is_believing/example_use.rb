require 'seeing_is_believing'
require 'seeing_is_believing/has_exception'

class SeeingIsBelieving
  class ExampleUse
    include HasException

    def initialize(body)
      self.body = body
    end

    def call
      result = SeeingIsBelieving.new(body).call
      self.exception = result.exception

      body.each_line.with_index 1 do |line, index|
        output << format_line(line.chomp, result[index])
      end

      output
    end

    def output
      @result ||= ''
    end

    private

    attr_accessor :body

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
