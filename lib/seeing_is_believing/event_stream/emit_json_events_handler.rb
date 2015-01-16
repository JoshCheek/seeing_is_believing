require 'json'
class SeeingIsBelieving
  module EventStream
    class EmitJsonEventsHandler
      attr_reader :stream, :flush

      def initialize(stream)
        @flush = true if stream.respond_to? :flush
        @stream = stream
      end

      def call(event)
        @stream << JSON.dump(event.as_json)
        @stream << "\n"
        @stream.flush if @flush
      end
    end
  end
end
