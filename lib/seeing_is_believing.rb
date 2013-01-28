require 'stringio'
require 'tmpdir'

require 'seeing_is_believing/result'
require 'seeing_is_believing/expression_list'
require 'seeing_is_believing/evaluate_by_moving_files'

# might not work on windows b/c of assumptions about line ends
class SeeingIsBelieving
  include TracksLineNumbersSeen
  BLANK_REGEX = /\A\s*\Z/

  def initialize(string_or_stream, options={})
    @string   = string_or_stream
    @stream   = to_stream string_or_stream
    @filename = options[:filename]
  end

  def call
    @memoized_result ||= begin
      program = ''
      program << expression_list.call until eof? || data_segment?
      program = record_exceptions_in program
      program << "\n" << the_rest_of_the_stream if data_segment?
      result_for program, min_line_number, max_line_number
    end
  end

  private

  attr_reader :stream

  def expression_list
    @expression_list ||= ExpressionList.new generator:   lambda { get_next_line },
                                            on_complete: lambda { |line, children, completions, line_number|
                                              track_line_number line_number
                                              expression = [line, *children, *completions].map(&:chomp).join("\n")
                                              if expression =~ BLANK_REGEX || SyntaxAnalyzer.ends_in_comment?(expression) || SyntaxAnalyzer.will_return?(expression)
                                                expression + "\n"
                                              else
                                                record_yahself(expression, line_number) + "\n"
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
      EvaluateByMovingFiles.new(program, filename).call.tap do |result|
        result.track_line_number min_line_number
        result.track_line_number max_line_number
      end
    end
  end

  def eof?
    peek_next_line.nil?
  end

  def data_segment?
    peek_next_line == '__END__'
  end

  def peek_next_line
    @next_line ||= begin
      line = stream.gets
      line && line.chomp
    end
  end

  def get_next_line
    if @next_line
      line = peek_next_line
      @next_line = nil
      line
    else
      peek_next_line && get_next_line
    end
  end

  def the_rest_of_the_stream
    get_next_line << "\n" << stream.read
  end
end
