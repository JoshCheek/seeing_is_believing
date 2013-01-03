require 'stringio'

require 'seeing_is_believing/result'
require 'seeing_is_believing/expression_list'

# might not work on windows b/c of assumptions about line ends
class SeeingIsBelieving
  def initialize(string_or_stream)
    @stream = to_stream string_or_stream
    @result = Result.new
  end

  def call
    @memoized_result ||= begin
      program = ''
      program << expression_list.call until stream.eof?
      $seeing_is_believing_current_result = @result # can we make this a threadlocal var on the class?
      TOPLEVEL_BINDING.eval record_exceptions_in(program), 'program.rb', 1
      @result
    end
  end

  private

  attr_reader :stream

  def expression_list
    @expression_list ||= ExpressionList.new generator: lambda { stream.gets.chomp },
                                            on_complete: lambda { |line, children, completions, line_number|
                                              @result.contains_line_number line_number
                                              expression = [line, *children, *completions].join("\n")
                                              if expression =~ /\A\s*\Z/ || SyntaxAnalyzer.ends_in_comment?(expression)
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
      "line_number = $!.backtrace.first[/:\\d+:/][1..-2].to_i;"\
      "$seeing_is_believing_current_result.record_exception line_number, $!;"\
    "end"
  end
end
