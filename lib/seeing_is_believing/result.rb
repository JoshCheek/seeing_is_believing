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

    # uhm, maybe switch to #each and including Enumerable?
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
end
