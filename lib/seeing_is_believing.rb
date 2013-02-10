require 'stringio'
require 'tmpdir'

require 'seeing_is_believing/queue'
require 'seeing_is_believing/result'
require 'seeing_is_believing/expression_list'
require 'seeing_is_believing/evaluate_by_moving_files'

# might not work on windows b/c of assumptions about line ends
class SeeingIsBelieving
  include TracksLineNumbersSeen
  BLANK_REGEX = /\A\s*\Z/

  def self.call(*args)
    new(*args).call
  end

  def initialize(string_or_stream, options={})
    @string          = string_or_stream
    @stream          = to_stream string_or_stream
    @matrix_filename = options[:matrix_filename]
    @filename        = options[:filename]
    @stdin           = to_stream options.fetch(:stdin, '')
    @line_number     = 1
  end

  # :( refactor me
  def call
    @memoized_result ||= begin
      # extract leading comments, leading =begin and magic comments can't be wrapped for exceptions without breaking
      leading_comments = ''
      while next_line_queue.peek =~ /^\s*#/
        leading_comments << next_line_queue.dequeue << "\n"
        @line_number += 1
      end
      while next_line_queue.peek == '=begin'
        lines = next_line_queue.dequeue << "\n"
        @line_number += 1
        until SyntaxAnalyzer.begin_and_end_comments_are_complete? lines
          lines << next_line_queue.dequeue << "\n"
          @line_number += 1
        end
        leading_comments << lines
      end

      # extract program
      program = ''
      until next_line_queue.peek.nil? || data_segment?
        expression, expression_size = expression_list.call
        program << expression
        track_line_number @line_number
        @line_number += expression_size
      end
      program = leading_comments + record_exceptions_in(program)

      # extract data segment
      program << "\n" << the_rest_of_the_stream if data_segment?
      result_for program, min_line_number, max_line_number
    end
  end

  private

  attr_reader :stream, :matrix_filename

  def expression_list
    @expression_list ||= ExpressionList.new get_next_line:  lambda { next_line_queue.dequeue },
                                            peek_next_line: lambda { next_line_queue.peek },
                                            on_complete:    lambda { |line, children, completions, offset|
                                              expression = [line, *children, *completions].map(&:chomp).join("\n")
                                              if do_not_record? expression
                                                expression + "\n"
                                              else
                                                record_yahself(expression, @line_number+offset) + "\n"
                                              end
                                            }
  end

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end

  def record_yahself(line, line_number)
    "($seeing_is_believing_current_result.record_result(#{line_number}, (#{line})))"
  end

  def record_exceptions_in(code)
    # must use newline after code, or comments will comment out rescue section
    "begin;"\
      "#{code}\n"\
    "rescue Exception;"\
      "line_number = $!.backtrace.grep(/\#{__FILE__}/).first[/:\\d+:/][1..-2].to_i;"\
      "$seeing_is_believing_current_result.record_exception line_number, $!;"\
    "end"
  end

  def result_for(program, min_line_number, max_line_number)
    Dir.mktmpdir "seeing_is_believing_temp_dir" do |dir|
      filename = @filename || File.join(dir, 'program.rb')
      EvaluateByMovingFiles.new(program, filename, input_stream: @stdin, matrix_filename: matrix_filename).call.tap do |result|
        result.track_line_number min_line_number
        result.track_line_number max_line_number
      end
    end
  end

  def eof?
    next_line_queue.peek.nil?
  end

  def data_segment?
    next_line_queue.peek == '__END__'
  end

  def next_line_queue
    @next_line_queue ||= Queue.new { (line = stream.gets) && line.chomp }
  end

  def the_rest_of_the_stream
    next_line_queue.dequeue << "\n" << stream.read
  end

  def do_not_record?(code)
    code =~ BLANK_REGEX                     ||
      SyntaxAnalyzer.ends_in_comment?(code) ||
      SyntaxAnalyzer.will_return?(code)     ||
      SyntaxAnalyzer.here_doc?(code)
  end
end
