require 'seeing_is_believing/hash_struct'

class SeeingIsBelieving
  module EventStream
    Event = HashStruct.anon do # one superclass to rule them all!
      def self.event_name
        raise NotImplementedError, "Subclass should have defined this!"
      end

      def event_name
        self.class.event_name
      end

      def as_json
        [event_name, to_h]
      end
    end

    module Events
      # A line was printed to stdout.
      class Stdout < Event
        def self.event_name
          :stdout
        end
        attributes :value
      end

      # A line was printed to stderr.
      class Stderr < Event
        def self.event_name
          :stderr
        end
        attributes :value
      end

      # The program will not record more results than this for a line.
      # Note that if this is hit, it will emit an unrecorded_result.
      class MaxLineCaptures < Event
        def self.event_name
          :max_line_captures
        end
        def as_json
          value, is_infinity = if self.value == Float::INFINITY
                                 [-1, true]
                               else
                                 [self.value, false]
                               end
          [event_name, {value: value, is_infinity: is_infinity}]
        end
        attribute :value
      end

      # Name of the file being evaluated.
      class Filename < Event
        def self.event_name
          :filename
        end
        attributes :value
      end

      # Number of lines in the program.
      class NumLines < Event
        def self.event_name
          :num_lines
        end
        attributes :value
      end

      # Version of SeeingIsBelieving used to evaluate the code.
      # Equivalent to `SeeingIsBelieving::VERSION`, and `seeing_is_believing --version`
      class SiBVersion < Event
        def self.event_name
          :sib_version
        end
        attributes :value
      end

      # Version of Ruby being used to evaluate the code.
      # Equivalent to `RUBY_VERSION`
      class RubyVersion < Event
        def self.event_name
          :ruby_version
        end
        attributes :value
      end

      # The process' exitstatus.
      class Exitstatus < Event
        def self.event_name
          :exitstatus
        end
        attributes :value
      end

      # The process timed out
      # note that you will probably not receive an exitstatus
      # if this occurs. Though it's hypothetically possible...
      # this is all asynchronous.
      class Timeout < Event
        def self.event_name
          :timeout
        end
        attributes :seconds
      end

      # Emitted when the process invokes exec.
      # Note that this could be a child process,
      # so it does not necessarily mean there won't be any more line results
      class Exec < Event
        def self.event_name
          :exec
        end
        attributes :args
      end

      # A line was executed, and its result recorded.
      # Currently, type will either be :inspect, or :pp
      # :pp is used by AnnotateMarkedLines to facilitate xmpfilter style.
      # If you're consuming the event stream, it's safe to assume type will always be :inspect
      # If you're using the library, it's whatever you've recorded it as (if you haven't changed this, it's :inspect)
      class LineResult < Event
        def self.event_name
          :line_result
        end
        attributes :type, :line_number, :inspected
      end

      # There were more results than we are emitting for this line / type of recording
      # See LineResult for explanation of types
      # This would occur because the line was executed more times than the max.
      class ResultsTruncated < Event
        def self.event_name
          :results_truncated
        end
        attributes :type, :line_number
      end

      # The program raised an exception and did not catch it.
      # Note that currently `ExitStatus` exceptions are not emitted.
      # That could change at some point as it seems like the stream consumer
      # should decide whether they care about that rather than the producer.
      class Exception < Event
        def self.event_name
          :exception
        end
        attributes :line_number, :class_name, :message, :backtrace
      end

      # The process's stdout stream was closed, there will be no more Stdout events.
      # "side" will either be :producer or :consumer
      class StdoutClosed < Event
        def self.event_name
          :stdout_closed
        end
        attributes :side
      end

      # The process's stderr stream was closed, there will be no more Stderr events.
      # "side" will either be :producer or :consumer
      class StderrClosed < Event
        def self.event_name
          :stderr_closed
        end
        attributes :side
      end

      # The process's event stream was closed, there will be no more events that come via the stream.
      # Currently, that's all events except Stdout, StdoutClosed, Stderr, StdoutClosed, ExitStatus, and Finished
      class EventStreamClosed < Event
        def self.event_name
          :event_stream_closed
        end
        attributes :side
      end

      # All streams are closed and the exit status is known.
      # There will be no more events.
      class Finished < Event
        def self.event_name
          :finished
        end
        attributes []
      end
    end
  end
end
