class SeeingIsBelieving
  class Result
    attr_reader :min_line_number, :max_line_number

    def initialize
      @min_line_number = @max_line_number = 1
    end

    def record_result(line_number, value)
      contains_line_number line_number
      results[line_number] << value.inspect
      value
    end

    def record_exception(line_number, exception)
      contains_line_number line_number
      @exception_line_number = line_number
      @exception = exception
    end

    def [](line_number)
      results[line_number]
    end

    # uhm, maybe switch to #each and including Enumerable?
    def to_a
      (min_line_number..max_line_number).map do |line_number|
        [line_number, [*self[line_number], *Array(exception_at line_number)]]
      end
    end

    def contains_line_number(line_number)
      @min_line_number = line_number if line_number < @min_line_number
      @max_line_number = line_number if line_number > @max_line_number
    end

    private

    def exception_at(line_number)
      return unless @exception_line_number == line_number
      @exception
    end

    def results
      @results ||= Hash.new { |hash, line_number| hash[line_number] = [] }
    end
  end
end
