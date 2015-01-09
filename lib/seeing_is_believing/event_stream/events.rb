class SeeingIsBelieving
  module EventStream
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
