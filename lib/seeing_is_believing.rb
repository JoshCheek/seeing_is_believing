require 'stringio'
require 'open3'

require 'seeing_is_believing/result'

class SeeingIsBelieving
  def initialize(string_or_stream)
    @stream      = to_stream string_or_stream
    @line_number = 0
    @program     = ''
    @result      = Result.new
  end

  def call
    # *sigh* 0.o
    @memoized_result ||= begin
      @program << build_next_expression_on('') until stream.eof?
      p @program
      $seeing_is_believing_current_result = @result # can we make this a threadlocal var on the class?
      TOPLEVEL_BINDING.eval @program
      # maybe just return the hash?
      @result.to_a
    end
  end

  private

  attr_reader :stream

  def build_next_expression_on(current_expression='')
    line = stream.gets
    @line_number += 1

    if valid_ruby? line
      current_expression << record_yahself(line, @line_number)
      return current_expression
    else
      current_expression << line
      build_next_expression_on current_expression until valid_ruby? current_expression
      record_yahself current_expression, @line_number
    end
  end

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end

  def valid_ruby?(expression)
    Open3.capture3('ruby -c', stdin_data: expression).last.success?
  end

  # might not work on windows
  def record_yahself(line, line_number)
    "$seeing_is_believing_current_result[#{line_number}] = (#{line.chomp})#{line[/(\n|\r)$/]}"
  end
end
