require 'seeing_is_believing/event_stream/events'
class SeeingIsBelieving
  module EventStream
    # Adapter between EventStream and Result
    module UpdateResult
      def self.call(result, event)
         case event
         when EventStream::Events::LineResult       then result.record_result(event.type, event.line_number, event.inspected)
         when EventStream::Events::UnrecordedResult then result.record_result(event.type, event.line_number, '...') # <-- is this really what I want?
         when EventStream::Events::Exception        then result.record_exception event.line_number, event.class_name, event.message, event.backtrace
         when EventStream::Events::Stdout           then result.stdout            << event.value
         when EventStream::Events::Stderr           then result.stderr            << event.value
         when EventStream::Events::MaxLineCaptures  then result.number_of_captures = event.value
         when EventStream::Events::Exitstatus       then result.exitstatus         = event.value
         when EventStream::Events::NumLines         then result.num_lines          = event.value
         when EventStream::Events::SiBVersion       then result.sib_version        = event.value
         when EventStream::Events::RubyVersion      then result.ruby_version       = event.value
         when EventStream::Events::Filename         then result.filename           = event.value
         when EventStream::Events::Finish           then result # No op
         else raise "Unknown event: #{event.inspect}"
         end
      end
    end
  end
end
