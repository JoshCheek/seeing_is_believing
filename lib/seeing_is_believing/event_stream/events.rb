require 'seeing_is_believing/strict_hash'

class SeeingIsBelieving
  module EventStream
    # actually, it might make sense for the consumer to emit a finish event when it knows there are no more
    # also might be nice for it to emit events when it knows different streams are done, just for informational purposes
    module Events
      Stdout           = StrictHash.for(:value)
      Stderr           = StrictHash.for(:value)
      MaxLineCaptures  = StrictHash.for(:value)
      Filename         = StrictHash.for(:value)
      NumLines         = StrictHash.for(:value)
      SiBVersion       = StrictHash.for(:value)
      RubyVersion      = StrictHash.for(:value)
      Exitstatus       = StrictHash.for(:value)
      LineResult       = StrictHash.for(:type, :line_number, :inspected)
      UnrecordedResult = StrictHash.for(:type, :line_number)
      Exception        = StrictHash.for(:line_number, :class_name, :message, :backtrace)
      Exec             = StrictHash.for(:args)
    end
  end
end
