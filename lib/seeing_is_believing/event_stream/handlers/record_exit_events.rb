require 'seeing_is_believing/event_stream/events'

class SeeingIsBelieving
  module EventStream
    module Handlers
      class RecordExitEvents
        attr_reader :exitstatus
        attr_reader :timeout_seconds

        def initialize(next_observer)
          @next_observer = next_observer
        end

        def call(event)
          case event
          when Events::Exitstatus
            @exitstatus = event.value
          when Events::Timeout
            @timeout_seconds = event.seconds
          end
          @next_observer.call(event)
        end
      end
    end
  end
end
