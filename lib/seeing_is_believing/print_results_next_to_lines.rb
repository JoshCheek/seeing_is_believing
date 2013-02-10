require 'seeing_is_believing/queue'
require 'seeing_is_believing/line_formatter'
require 'seeing_is_believing/has_exception'

class SeeingIsBelieving
  class PrintResultsNextToLines
    include HasException

       STDOUT_PREFIX = '# >>'
       STDERR_PREFIX = '# !>'
    EXCEPTION_PREFIX = '# ~>'
       RESULT_PREFIX = '# =>'

    def self.remove_previous_output_from(string)
      string.gsub(/\s+(#{EXCEPTION_PREFIX}|#{RESULT_PREFIX}).*?$/, '')
            .gsub(/\n?(^#{STDOUT_PREFIX}[^\n]*\r?\n?)+/m,          '')
            .gsub(/\n?(^#{STDERR_PREFIX}[^\n]*\r?\n?)+/m,          '')
    end


    def self.method_from_options(*args)
      define_method(args.first) { options.fetch *args }
    end

    method_from_options :filename, nil
    method_from_options :start_line
    method_from_options :end_line
    method_from_options :line_length,   Float::INFINITY
    method_from_options :result_length, Float::INFINITY


    def initialize(body, stdin, file_result, options={})
      self.body        = body
      self.stdin       = stdin
      self.options     = options
      self.file_result = file_result
    end

    def new_body
      @new_body ||= ''
    end

    def call
      add_each_line_until_start_or_data_segment
      add_lines_with_results_until_end_or_data_segment
      add_lines_until_data_segment
      add_stdout
      add_stderr
      add_remaining_lines
      return new_body
    end

    private

    attr_accessor :body, :file_result, :stdin, :options

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
    def max_source_line_length
      @max_source_line_length ||= 2 + body.each_line
                                          .map(&:chomp)
                                          .select.with_index(1) { |line, index| start_line <= index && index <= end_line }
                                          .take_while { |line| not start_of_data_segment? line }
                                          .select { |line| not (line == "=begin") .. (line == "=end") }
                                          .reject { |line| SyntaxAnalyzer.ends_in_comment? line }
                                          .map(&:length)
                                          .max
    end

    def add_stdout
      return unless file_result.has_stdout?
      new_body << "\n"
      file_result.stdout.each_line do |line|
        new_body << LineFormatter.new('', "#{STDOUT_PREFIX} ", line.chomp, options).call << "\n"
      end
    end

    def add_stderr
      return unless file_result.has_stderr?
      new_body << "\n"
      file_result.stderr.each_line do |line|
        new_body << LineFormatter.new('', "#{STDERR_PREFIX} ", line.chomp, options).call << "\n"
      end
    end

    def format_line(line, line_results)
      options = options().merge source_length: max_source_line_length
      formatted_line = if line_results.has_exception?
                         result = sprintf "%s: %s", line_results.exception.class, line_results.exception.message
                         LineFormatter.new(line, "#{EXCEPTION_PREFIX} ", result, options).call
                       elsif line_results.any?
                         LineFormatter.new(line, "#{RESULT_PREFIX} ", line_results.join(', '), options).call
                       else
                         line
                       end
      formatted_line + "\n"
    end

  end
end
