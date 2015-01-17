require 'json'
class SeeingIsBelieving
  module EventStream
    class ObserverStreamJsonEvents
      attr_reader :stream

      def initialize(stream)
        @flush          = true if stream.respond_to? :flush
        @stream         = stream
        @has_exception  = false
        @exitstatus     = :not_yet_seen
      end

      def call(event)
        write_event    event
        record_outcome event
      end

      def return_value
        self
      end

      def has_exception?
        true
      end

      def exitstatus
        @exitstatus
      end

      private

      def write_event(event)
        @stream << JSON.dump(event.as_json)
        @stream << "\n"
        @stream.flush if @flush
      end

      def record_outcome(event)
        case event
        when Events::Exception  then @has_exception = true
        when Events::Exitstatus then @exitstatus = event.value
        end
      end
    end
  end
end
