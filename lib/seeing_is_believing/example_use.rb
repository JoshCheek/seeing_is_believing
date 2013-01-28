require 'seeing_is_believing'
require 'seeing_is_believing/has_exception'

class SeeingIsBelieving
  class ExampleUse
    include HasException

       STDOUT_PREFIX = '# >>'
       STDERR_PREFIX = '# !>'
    EXCEPTION_PREFIX = '# ~>'
       RESULT_PREFIX = '# =>'

    def initialize(body, filename=nil)
      self.body     = remove_previous_output_from body
      self.filename = filename
    end

    def output
      @output ||= ''
    end

    def call
      inherit_exception
      print_each_line_until_data_segment
      print_stdout
      print_stderr
      print_data_segment
      output
    end

    private

    attr_accessor :body, :filename

    def file_result
      @file_result ||= SeeingIsBelieving.new(body, filename: filename).call
    end

    def remove_previous_output_from(string)
      string.gsub(/\s+(#{EXCEPTION_PREFIX}|#{RESULT_PREFIX}).*?$/, '')
            .gsub(/(\n)?(^#{STDOUT_PREFIX}[^\n]*\r?\n?)+/m,        '')
            .gsub(/(\n)?(^#{STDERR_PREFIX}[^\n]*\r?\n?)+/m,        '')
    end

    def inherit_exception
      self.exception = file_result.exception
    end

    def print_each_line_until_data_segment
      body.each_line.with_index 1 do |line, index|
        break if start_of_data_segment? line
        output << format_line(line.chomp, file_result[index])
      end
    end

    def print_data_segment
      body.each_line
          .drop_while { |line| not start_of_data_segment? line }
          .each { |line| output << line }
    end

    def start_of_data_segment?(line)
      line.chomp == '__END__'
    end

    def print_stdout
      return unless file_result.has_stdout?
      output << "\n"
      file_result.stdout.each_line { |line| output << "#{STDOUT_PREFIX} #{line}" }
    end

    def print_stderr
      return unless file_result.has_stderr?
      output << "\n"
      file_result.stderr.each_line { |line| output << "#{STDERR_PREFIX} #{line}" }
    end

    # max line length of the body + 2 spaces for padding
    def line_length
      @line_length ||= 2 + body.each_line
                               .map(&:chomp)
                               .take_while { |line| not start_of_data_segment? line }
                               .reject { |line| SyntaxAnalyzer.ends_in_comment? line }
                               .map(&:length)
                               .max
    end

    def format_line(line, line_results)
      if line_results.has_exception?
        sprintf "%-#{line_length}s#{EXCEPTION_PREFIX} %s: %s\n", line, line_results.exception.class, line_results.exception.message
      elsif line_results.any?
        sprintf "%-#{line_length}s#{RESULT_PREFIX} %s\n", line, line_results.join(', ')
      else
        line + "\n"
      end
    end
  end
end
