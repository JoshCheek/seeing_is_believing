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
      expression_list = ExpressionList.new
      program = ''
      program << get_next_expression(expression_list) until stream.eof?
      $seeing_is_believing_current_result = @result # can we make this a threadlocal var on the class?
      TOPLEVEL_BINDING.eval program
      @result.to_a # maybe just return the result?
    end
  end

  private

  attr_reader :stream

  def get_next_expression(expression_list)
    expression_list.push(stream.gets.chomp,
                         generate:    lambda { get_next_expression expression_list; '' },
                         on_complete: lambda { |line, children, completions, line_number|
                           expression = line + children.join("\n") + completions.join("\n")
                           record_yahself expression, line_number
                         })
  end

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end

  # might not work on windows
  def record_yahself(line, line_number)
    "($seeing_is_believing_current_result[#{line_number}] = (#{line}))\n"
  end
end
