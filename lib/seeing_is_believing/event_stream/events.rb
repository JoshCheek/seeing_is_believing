class SeeingIsBelieving
  module EventStream
    # actually, it might make sense for the consumer to emit a finish event when it knows there are no more
    # also might be nice for it to emit events when it knows different streams are done, just for informational purposes
    module Events
      LineResult       = Struct.new(:type, :line_number, :inspected)
      UnrecordedResult = Struct.new(:type, :line_number)
      Stdout           = Struct.new(:value)
      Stderr           = Struct.new(:value)
      MaxLineCaptures  = Struct.new(:value)
      Filename         = Struct.new(:value)
      NumLines         = Struct.new(:value)
      SiBVersion       = Struct.new(:value)
      RubyVersion      = Struct.new(:value)
      Exitstatus       = Struct.new(:value)
      Exception        = Struct.new(:line_number, :class_name, :message, :backtrace)
      Exec             = Struct.new(:args)
    end
  end
end
