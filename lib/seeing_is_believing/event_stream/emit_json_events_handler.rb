require 'json'
class SeeingIsBelieving
  module EventStream
    class EmitJsonEventsHandler
      attr_reader :stream

      def initialize(stream)
        @flush = true if stream.respond_to? :flush
        @stream = stream
      end

      def call(event)
        @stream << JSON.dump(event.as_json)
        @stream << "\n"
        @stream.flush if @flush
      end

      def ==(other)
        other.kind_of?(self.class) && other.stream == stream
      end
    end
  end
end
