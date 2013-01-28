require 'forwardable'
require 'seeing_is_believing/has_exception'
require 'seeing_is_believing/tracks_line_numbers_seen'

class SeeingIsBelieving
  class Result

    class Line
      include HasException

      extend Forwardable
      def_delegators :@array, :[], :<<, :any?, :join, :to_ary, :to_a

      def initialize
        @array ||= []
      end

      def ==(ary_or_line)
        if Array === ary_or_line
          @array == ary_or_line
        else
          @array == ary_or_line &&
            has_exception? == ary_or_line.has_exception?
        end
      end
    end

    include HasException
    include TracksLineNumbersSeen

    attr_accessor :stdout, :stderr

    def has_stdout?
      stdout && !stdout.empty?
    end

    def has_stderr?
      stderr && !stderr.empty?
    end

    def initialize
      @min_line_number = @max_line_number = 1
    end

    def record_result(line_number, value)
      track_line_number line_number
      results(line_number) << value.inspect
      value
    end

    def record_exception(line_number, exception)
      self.exception = exception
      track_line_number line_number
      results(line_number).exception = exception
    end

    def [](line_number)
      results(line_number)
    end

    # probably not really useful, just exists to satisfy the tests, which specified too simple of an interface
    def to_a
      (min_line_number..max_line_number).map do |line_number|
        [line_number, [*self[line_number].to_ary, *Array(self[line_number].exception)]]
      end
    end

    private

    def results(line_number)
      @results ||= Hash.new
      @results[line_number] ||= Line.new
    end
  end
end
