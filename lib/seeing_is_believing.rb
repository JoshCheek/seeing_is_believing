require 'stringio'
require 'open3'

class SeeingIsBelieving
  class Result
    attr_reader :min_index, :max_index

    def initialize
      @min_index = @max_index = 1
    end

    def []=(index, value)
      contains_index index
      hash[index] << value.inspect
    end

    def [](index)
      hash[index]
    end

    def to_a
      (min_index..max_index).map { |index| [index, self[index]] }
    end

    private

    def contains_index(index)
      @min_index = index if index < @min_index
      @max_index = index if index > @max_index
    end

    def hash
      @hash ||= Hash.new { |hash, index| hash[index] = [] }
    end
  end

  def initialize(string_or_stream)
    @stream = to_stream string_or_stream
  end

  def call
    # *sigh* 0.o
    @result ||= begin
      line_number = 0
      program     = ''
      result      = Result.new
      until @stream.eof?
        line_number        += 1
        line               = @stream.gets
        current_expression = line
        until valid_ruby? current_expression
          line_number         += 1
          line                = @stream.gets
          line                = record_yahself line, line_number if valid_ruby? line
          current_expression  << line
        end
        program << record_yahself(current_expression, line_number)
      end
      $seeing_is_believing_current_result = result # can we make this a threadlocal var on the class?
      TOPLEVEL_BINDING.eval program
      # maybe just return the hash?
      result.to_a
    end
  end

  private

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
