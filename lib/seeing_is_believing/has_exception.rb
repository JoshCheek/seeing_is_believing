class SeeingIsBelieving
  RecordedException = Struct.new :line_number, :class_name, :message, :backtrace

  module HasException
    attr_accessor :exception
    alias has_exception? exception
  end
end
