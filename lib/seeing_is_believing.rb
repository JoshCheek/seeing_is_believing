require 'stringio'

require 'seeing_is_believing/result'
require 'seeing_is_believing/expression_list'

class SeeingIsBelieving
  def initialize(string_or_stream)
    @stream      = to_stream string_or_stream
    @result      = Result.new
  end

  def call
    @memoized_result ||= begin
      expression_list = ExpressionList.new generator: lambda { stream.gets.chomp },
                                           on_complete: lambda { |line, children, completions, line_number|
                                             expression = [line, *children, *completions].join("\n")
                                             if expression == ''
                                               expression
                                             else
                                               record_yahself expression, line_number
                                             end
                                           }
      program = ''
      program << expression_list.call until stream.eof?
      $seeing_is_believing_current_result = @result # can we make this a threadlocal var on the class?
      TOPLEVEL_BINDING.eval program
      @result.to_a # maybe just return the result?
    end
  end

  private

  attr_reader :stream

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end

  # might not work on windows
  def record_yahself(line, line_number)
    "($seeing_is_believing_current_result[#{line_number}] = (#{line}))\n"
  end
end
