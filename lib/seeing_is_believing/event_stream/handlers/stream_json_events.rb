require 'json'
class SeeingIsBelieving
  module EventStream
    module Handlers
      class StreamJsonEvents
        attr_reader :stream

        def initialize(stream)
          @flush          = true if stream.respond_to? :flush
          @stream         = stream
          @has_exception  = false
          @exitstatus     = :not_yet_seen
        end

        def call(event)
          @stream << JSON.dump(event.as_json)
          @stream << "\n"
          @stream.flush if @flush
        end
      end
    end
  end
end
