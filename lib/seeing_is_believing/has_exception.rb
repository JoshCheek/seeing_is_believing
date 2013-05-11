class SeeingIsBelieving

  # We cannot serialize the actual exception because we do not have any guarantee that its class is defined on the SIB side,
  # so we must use simpler data structures (Strings and arrays)
  RecordedException = Struct.new :class_name, :message, :backtrace

  module HasException
    attr_accessor :exception
    alias has_exception? exception
  end
end
