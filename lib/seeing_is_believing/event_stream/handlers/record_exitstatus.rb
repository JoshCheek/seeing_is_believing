class SeeingIsBelieving
  module EventStream
    module Handlers
      class RecordExitStatus
        attr_reader :exitstatus

        def initialize(next_observer)
          @next_observer = next_observer
        end

        def call(event)
          @exitstatus = event.value if event.event_name == :exitstatus
          @next_observer.call(event)
        end
      end
    end
  end
end
