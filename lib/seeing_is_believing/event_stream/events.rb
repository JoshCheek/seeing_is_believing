class SeeingIsBelieving
  module EventStream
    module Events
      LineResult       = Struct.new(:type, :line_number, :inspected)
      UnrecordedResult = Struct.new(:type, :line_number)
      Stdout           = Struct.new(:value)
      Stderr           = Struct.new(:value)
      MaxLineCaptures  = Struct.new(:value)
      NumLines         = Struct.new(:value)
      Version          = Struct.new(:value)
      Exitstatus       = Struct.new(:value)
      Exception        = Struct.new(:line_number, :class_name, :message, :backtrace)
      Finish           = Class.new
    end
  end
end
