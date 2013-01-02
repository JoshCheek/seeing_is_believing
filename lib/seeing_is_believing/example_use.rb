require 'seeing_is_believing'

class SeeingIsBelieving
  class ExampleUse
    attr_accessor :exception

    def initialize(body)
      self.body = body
    end

    def call
      body.each_line.with_index 1 do |line, index|
        line_results = results[index]
        self.exception = line_results.exception if line_results.has_exception?
        output << format_line(line.chomp, line_results)
      end
      output
    end

    def output
      @result ||= ''
    end

    alias has_exception? exception

    private

    attr_accessor :body

    def results
      @results ||= SeeingIsBelieving.new(body).call
    end

    # max line length of the body + 2 spaces for padding
    def line_length
      @line_length ||= 2 + body.each_line.map(&:chomp).map(&:length).max
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
