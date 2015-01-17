class SeeingIsBelieving
  module EventStream
    module ObserverNull
      extend self
      def call(event)
        # no op
      end
    end
  end
end
