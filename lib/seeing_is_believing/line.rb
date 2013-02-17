require 'seeing_is_believing/has_exception'
class SeeingIsBelieving
  # thin wrapper over an array, used by the result
  class Line
    def self.[](*elements)
      new(elements)
    end

    include HasException
    include Enumerable

    # delegate all methods to the array, but return self where the array would be returned
    Array.instance_methods(false).sort.each do |method_name|
      define_method method_name do |*args, &block|
        result = @array.__send__ method_name, *args, &block
        result.equal?(@array) ? self : result
      end
    end

    def to_a
      @array.dup
    end
    alias to_ary to_a

    def initialize(array = [])
      @array = array.dup
    end

    def ==(ary_or_line)
      return @array == ary_or_line if Array === ary_or_line
      ary_or_line == @array && exception == ary_or_line.exception
    end

    def inspect
      inspected_exception = has_exception? ? "#{exception.class}:#{exception.message.inspect}" : "no exception"
      "#<SIB:Line#{@array.inspect} #{inspected_exception}>"
    end
  end
end
