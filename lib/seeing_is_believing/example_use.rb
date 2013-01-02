require 'seeing_is_believing'

class SeeingIsBelieving
  class ExampleUse
    def initialize(body)
      self.body = body
    end

    def call
      body.each_line.with_index 1 do |line, index|
        write_line line.chomp, results[index]
      end
      output
    end

    private

    attr_accessor :body

    def results
      @results ||= SeeingIsBelieving.new(body).call
    end

    def output
      @result ||= ''
    end

    def write_line(line, results)
      if results.any?
        output << sprintf("%-#{line_length}s# => %s\n", line, results.join(', '))
      else
        output << line << "\n"
      end
    end

    def line_length
      @line_length ||= body.each_line.map(&:chomp).map(&:length).max + 2
    end
  end
end
