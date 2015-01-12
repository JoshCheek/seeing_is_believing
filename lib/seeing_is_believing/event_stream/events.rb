require 'seeing_is_believing/strict_hash'

class SeeingIsBelieving
  module EventStream
    Event = StrictHash.anon # one superclass to rule them all!

    module Events
      # actually, it might make sense for the consumer to emit a finish event when it knows there are no more
      # also might be nice for it to emit events when it knows different streams are done, just for informational purposes
      Stdout           = Event.for :value
      Stderr           = Event.for :value
      MaxLineCaptures  = Event.for :value
      Filename         = Event.for :value
      NumLines         = Event.for :value
      SiBVersion       = Event.for :value
      RubyVersion      = Event.for :value
      Exitstatus       = Event.for :value
      Exec             = Event.for :args
      UnrecordedResult = Event.for :type, :line_number
      LineResult       = Event.for :type, :line_number, :inspected
      Exception        = Event.for :line_number, :class_name, :message, :backtrace
    end
  end
end
