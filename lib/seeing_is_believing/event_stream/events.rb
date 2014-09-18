class SeeingIsBelieving
  module EventStream
    module Events
      LineResult       = Struct.new(:type, :line_number, :inspected)
      UnrecordedResult = Struct.new(:type, :line_number)
      Stdout           = Struct.new(:stdout) # TODO: rename to value
      Stderr           = Struct.new(:stderr) # TODO: rename to value
      BugInSiB         = Struct.new(:value)
      MaxLineCaptures  = Struct.new(:value)
      NumLines         = Struct.new(:value)
      Exitstatus       = Struct.new(:value)
      Exception        = Struct.new(:line_number, :class_name, :message, :backtrace)
      Finish           = Class.new
    end
  end
end
