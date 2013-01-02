require 'seeing_is_believing'

class SeeingIsBelieving
  class ExampleUse
    attr_accessor :exception

    def initialize(body)
      self.body = body
    end

    def call
      body.each_line.with_index 1 do |line, index|
        output << format_line(line.chomp, results[index])
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

    def format_line(line, results)
      if results.any?
        sprintf "%-#{line_length}s# => %s\n", line, results.join(', ')
      elsif results.has_exception?
        self.exception = results.exception
        sprintf "%-#{line_length}s# ~> %s: %s\n", line, results.exception.class, results.exception.message
      else
        line + "\n"
      end
    end
  end
end
