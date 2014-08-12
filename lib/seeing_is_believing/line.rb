require 'seeing_is_believing/has_exception'

class SeeingIsBelieving
  # thin wrapper over an array, used by the result
  class Line
    include HasException
    include Enumerable

    # delegate all methods to the array, but return self where the array would be returned
    Array.instance_methods(false).sort.each do |method_name|
      define_method method_name do |*args, &block|
        result = @array.__send__ method_name, *args, &block
        result.equal?(@array) ? self : result
      end
    end

    def to_float(n)
      return n unless n == Float::INFINITY
      'FUCKING_INFINITY_AND_JESUS_FUCKING_CHRIST_JSON_AND_MARSHAL_AND_YAML_WHAT_THE_FUCK?'
    end

    def from_float(n)
      return n if n.kind_of? Float
      Float::INFINITY
    end

    def to_primitive
      { 'array'                  => @array,
        'max_number_of_captures' => to_float(@max_number_of_captures),
        'num_results'            => @num_results,
        'total_size'             => @total_size,
        'exception'              => (exception && exception.to_primitive)
      }
    end

    def from_primitive(primitive)
      @array                  = primitive['array']
      @max_number_of_captures = from_float primitive['max_number_of_captures']
      @num_results            = primitive['num_results']
      @total_size             = primitive['total_size']
      @exception              = RecordedException.from_primitive primitive['exception']
    end

    def to_a
      @array.dup
    end
    alias to_ary to_a

    def initialize(array = [], max_number_of_captures=Float::INFINITY)
      @array                  = []
      @max_number_of_captures = max_number_of_captures
      @num_results            = 0
      @total_size             = 0
      array.each { |element| record_result element }
    end

    def record_result(value)
      begin
        inspected = value.inspect.to_str # only invoke inspect once, b/c the inspection may be recorded
      rescue NoMethodError
        inspected = "#<no inspect available>"
      end

      if    size <  @max_number_of_captures then @array << inspected
      elsif size == @max_number_of_captures then @array << '...'
      end
      @num_results += 1
      @total_size  += inspected.size
      self
    end

    def ==(ary_or_line)
      return @array == ary_or_line if Array === ary_or_line
      ary_or_line == @array && exception == ary_or_line.exception
    end

    def inspect
      inspected_exception = has_exception? ? "#{exception.class}:#{exception.message.inspect}" : "no exception"
      "#<SIB:Line#{@array.inspect} (#@num_results, #@total_size) #{inspected_exception}>"
    end
  end
end
