require 'seeing_is_believing/code'
require 'seeing_is_believing/binary/data_structures'
require 'seeing_is_believing/binary/remove_annotations'
require 'seeing_is_believing/event_stream/handlers/record_exit_events'

class SeeingIsBelieving
  module Binary
    class MustEvaluateFirst < SeeingIsBelievingError
      def initialize(method)
        super "Cannot call #{method} on engine until it has evaluated the program."
      end
    end

    class Engine
      def initialize(config)
        self.config = config
      end

      def cleaned_body
        @cleaned_body ||= if missing_newline?
                            normalized_cleaned_body.chomp!
                          else
                            normalized_cleaned_body
                          end
      end

      def syntax_error?
        code.syntax.invalid?
      end

      def syntax_error
        return unless syntax_error?
        SyntaxErrorMessage.new line_number: code.syntax.line_number,
                               explanation: code.syntax.error_message,
                               filename:    config.lib_options.filename
      end

      def evaluate!
        @evaluated || begin
          SeeingIsBelieving.call normalized_cleaned_body,
                                 config.lib_options.merge(event_handler: record_exit_events)
          @timed_out = false
          @evaluated = true
        end
      rescue Timeout::Error
        @timed_out = true
        @evaluated = true
      ensure return self unless $! # idk, maybe too tricky, but was really annoying putting it in three places
      end

      def timed_out?
        @evaluated || raise(MustEvaluateFirst.new __method__)
        !!timeout_seconds
      end

      def timeout_seconds
        @evaluated || raise(MustEvaluateFirst.new __method__)
        record_exit_events.timeout_seconds
      end

      def result
        @evaluated || raise(MustEvaluateFirst.new __method__)
        config.lib_options.event_handler.result # The stream handler will not have a result (implies this was used wrong)
      end

      def annotated_body
        @annotated_body ||= begin
          @evaluated || raise(MustEvaluateFirst.new __method__)
          annotated = config.annotator.call normalized_cleaned_body,
                                            result,
                                            config.annotator_options.to_h
          annotated.chomp! if missing_newline?
          annotated
        end
      end

      def exitstatus
        @evaluated || raise(MustEvaluateFirst.new __method__)
        record_exit_events.exitstatus
      end

      private

      attr_accessor :config

      def missing_newline?
        @missing_newline ||= !config.body.end_with?("\n")
      end

      def code
        @code ||= Code.new(normalized_cleaned_body, config.filename)
      end

      def record_exit_events
        @record_exit_events ||= SeeingIsBelieving::EventStream::Handlers::RecordExitEvents.new config.lib_options.event_handler
      end

      def normalized_cleaned_body
        @normalized_cleaned_body ||= begin
          body_with_nl = config.body
          body_with_nl += "\n" if missing_newline?
          RemoveAnnotations.call body_with_nl,
                                 config.remove_value_prefixes,
                                 config.markers
        end
      end
    end
  end
end
