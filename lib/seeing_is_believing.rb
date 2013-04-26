require 'stringio'
require 'tmpdir'
require 'timeout'

require 'seeing_is_believing/queue'
require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
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
    @require         = options.fetch :require, []
    @load_path       = options.fetch :load_path, []
    @encoding        = options.fetch :encoding, nil
    @line_number     = 1
    @timeout         = options[:timeout]
  end

  # I'd like to refactor this, but I was unsatisfied with the three different things I tried.
  # In the end, I prefer keeping all manipulation of the line number here in the main function
  # And I like that the higher-level construct of how the program gets built can be found here.
  def call
    @memoized_result ||= begin
      leading_comments = ''

      # extract leading comments (e.g. encoding) so they don't get wrapped in begin/rescue/end
      while SyntaxAnalyzer.line_is_comment?(next_line_queue.peek)
        leading_comments << next_line_queue.dequeue << "\n"
        @line_number += 1
      end

      # extract leading =begin/=end so they don't get wrapped in begin/rescue/end
      while SyntaxAnalyzer.begins_multiline_comment?(next_line_queue.peek)
        lines = next_line_queue.dequeue << "\n"
        @line_number += 1
        until SyntaxAnalyzer.begin_and_end_comments_are_complete? lines
          lines << next_line_queue.dequeue << "\n"
          @line_number += 1
        end
        leading_comments << lines
      end

      # extract program body
      body = ''
      until next_line_queue.empty? || data_segment?
        expression, expression_size = expression_list.call
        body << expression
        track_line_number @line_number
        @line_number += expression_size
      end

      # extract data segment
      data_segment = ''
      data_segment = "\n#{the_rest_of_the_stream}" if data_segment?

      # build the program
      program = leading_comments << record_exceptions_in(body) << data_segment

      # return the result
      result_for program, max_line_number
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
      "line_number = $!.backtrace.grep(/\#{__FILE__}/).first[/:\\d+/][1..-1].to_i;"\
      "$seeing_is_believing_current_result.record_exception line_number, $!;"\
    "end"
  end

  def result_for(program, max_line_number)
    Dir.mktmpdir "seeing_is_believing_temp_dir" do |dir|
      filename = @filename || File.join(dir, 'program.rb')
      EvaluateByMovingFiles.new(program,
                                filename,
                                input_stream:    @stdin,
                                matrix_filename: matrix_filename,
                                require:         @require,
                                load_path:       @load_path,
                                encoding:        @encoding,
                                timeout:         @timeout)
                           .call
                           .track_line_number(max_line_number)
    end
  end

  def eof?
    next_line_queue.peek.nil?
  end

  def data_segment?
    SyntaxAnalyzer.begins_data_segment?(next_line_queue.peek)
  end

  def next_line_queue
    @next_line_queue ||= Queue.new { (line = stream.gets) && line.chomp }
  end

  def the_rest_of_the_stream
    next_line_queue.dequeue << "\n" << stream.read
  end

  def do_not_record?(code)
    code =~ BLANK_REGEX                           ||
      SyntaxAnalyzer.ends_in_comment?(code)       ||
      SyntaxAnalyzer.void_value_expression?(code) ||
      SyntaxAnalyzer.here_doc?(code)
  end
end
