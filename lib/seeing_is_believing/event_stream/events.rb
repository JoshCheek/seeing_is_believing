require 'seeing_is_believing/hash_struct'

class SeeingIsBelieving
  module EventStream
    Event = HashStruct.anon # one superclass to rule them all!

    module Events
      Stdout            = Event.for :value
      Stderr            = Event.for :value
      MaxLineCaptures   = Event.for :value
      Filename          = Event.for :value
      NumLines          = Event.for :value
      SiBVersion        = Event.for :value
      RubyVersion       = Event.for :value
      Exitstatus        = Event.for :value
      Exec              = Event.for :args
      UnrecordedResult  = Event.for :type, :line_number
      LineResult        = Event.for :type, :line_number, :inspected
      Exception         = Event.for :line_number, :class_name, :message, :backtrace
      StdoutClosed      = Event.for :side
      StderrClosed      = Event.for :side
      EventStreamClosed = Event.for :side
      Finished          = Event.anon
    end
  end
end
