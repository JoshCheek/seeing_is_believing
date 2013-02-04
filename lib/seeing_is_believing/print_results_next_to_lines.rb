require 'seeing_is_believing'
require 'seeing_is_believing/queue'
require 'seeing_is_believing/has_exception'

class SeeingIsBelieving
  class PrintResultsNextToLines
    include HasException

       STDOUT_PREFIX = '# >>'
       STDERR_PREFIX = '# !>'
    EXCEPTION_PREFIX = '# ~>'
       RESULT_PREFIX = '# =>'

    def initialize(body, stdin, options={})
      self.body       = remove_previous_output_from body
      self.stdin      = stdin
      self.filename   = options.fetch :filename,   nil
      self.start_line = options.fetch :start_line
      self.end_line   = options.fetch :end_line
    end

    def new_body
      @new_body ||= ''
    end

    def call
      evaluate_program
      inherit_exception
      add_each_line_until_start_or_data_segment
      add_lines_with_results_until_end_or_data_segment
      add_lines_until_data_segment
      add_stdout
      add_stderr
      add_remaining_lines
      return new_body
    end

    private

    attr_accessor :body, :filename, :file_result, :stdin, :start_line, :end_line

    def evaluate_program
      self.file_result = SeeingIsBelieving.new(body, filename: filename, stdin: stdin).call
    end

    def inherit_exception
      self.exception = file_result.exception
    end

    def add_each_line_until_start_or_data_segment
      line_queue.until { |line, line_number| line_number == start_line || start_of_data_segment?(line) }
                .each  { |line, line_number| new_body << line }
    end

    def add_lines_with_results_until_end_or_data_segment
      line_queue.until { |line, line_number| end_line < line_number || start_of_data_segment?(line) }
                .each  { |line, line_number| new_body << format_line(line.chomp, file_result[line_number]) }
    end

    def add_lines_until_data_segment
      line_queue.until { |line, line_number| start_of_data_segment?(line) }
                .each  { |line, line_number| new_body << line }
    end

    def add_remaining_lines
      line_queue.each { |line, line_number| new_body << line }
    end

    def line_queue
      @line_queue ||= Queue.new &body.each_line.with_index(1).to_a.method(:shift)
    end

    def start_of_data_segment?(line)
      line.chomp == '__END__'
    end

    # max line length of the lines to output (exempting coments) + 2 spaces for padding
    def line_length
      @line_length ||= 2 + body.each_line
                               .map(&:chomp)
                               .select.with_index(1) { |line, index| start_line <= index && index <= end_line }
                               .take_while { |line| not start_of_data_segment? line }
                               .select { |line| not (line == "=begin") .. (line == "=end") }
                               .reject { |line| SyntaxAnalyzer.ends_in_comment? line }
                               .map(&:length)
                               .max
    end

    def remove_previous_output_from(string)
      string.gsub(/\s+(#{EXCEPTION_PREFIX}|#{RESULT_PREFIX}).*?$/, '')
            .gsub(/\n?(^#{STDOUT_PREFIX}[^\n]*\r?\n?)+/m,          '')
            .gsub(/\n?(^#{STDERR_PREFIX}[^\n]*\r?\n?)+/m,          '')
    end

    def add_stdout
      return unless file_result.has_stdout?
      new_body << "\n"
      file_result.stdout.each_line { |line| new_body << "#{STDOUT_PREFIX} #{line}" }
    end

    def add_stderr
      return unless file_result.has_stderr?
      new_body << "\n"
      file_result.stderr.each_line { |line| new_body << "#{STDERR_PREFIX} #{line}" }
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
