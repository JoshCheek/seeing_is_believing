class SeeingIsBelieving

  # We cannot serialize the actual exception because we do not have any guarantee that its class is defined on the SIB side,
  # so we must use simpler data structures (Strings and arrays)
  RecordedException = Struct.new :class_name, :message, :backtrace do
    def self.from_primitive(primitive)
      return nil unless primitive
      exception = new
      exception.class_name = primitive['class_name']
      exception.message    = primitive['message']
      exception.backtrace  = primitive['backtrace']
      exception
    end

    def to_primitive
      { 'class_name' => class_name,
        'message'    => message,
        'backtrace'  => backtrace,
      }
    end
  end

  module HasException
    attr_accessor :exception
    alias has_exception? exception
  end
end
