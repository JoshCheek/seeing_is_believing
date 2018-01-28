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
                            normalized_cleaned_body.chomp
                          else
                            normalized_cleaned_body
                          end
      end


      require 'seeing_is_believing/binary/rewrite_comments'
      require 'seeing_is_believing/binary/format_comment'
      module ToggleMark
        def self.call(options)
          options = options.dup
          body    = options.delete :body
          line    = options.delete :line
          markers = options.delete :markers
          alignment_strategy = options.delete :alignment_strategy

          marker_regexes = markers.values.map(&:regex)
          RewriteComments.call body, include_lines: [line] do |comment|
            if line == comment.line_number && marker_regexes.any? { |r| r =~ comment.text }
              new_comment = ''
            elsif line == comment.line_number && comment.text.empty?
              new_comment = FormatComment.call(
                comment.whitespace_col,
                markers.value.prefix,
                '',
                options.merge(
                  pad_to: alignment_strategy.line_length_for(comment.line_number)
                ),
              )
            elsif line == comment.line_number
              new_comment = comment.whitespace + comment.text
            elsif match = markers.value.regex.match(comment.text)
              new_comment = FormatComment.call(
                comment.whitespace_col,
                markers.value.prefix,
                match.post_match,
                options.merge(
                  pad_to: alignment_strategy.line_length_for(comment.line_number)
                )
              )
            else
              new_comment = comment.whitespace + comment.text
            end
            [new_comment[/^\s*/], new_comment.lstrip]
          end
        end
      end

      def toggled_mark
        body = config.body
        body         += "\n" if missing_newline?
        toggled = ToggleMark.call(
          body:               body,
          line:               config.toggle_mark,
          markers:            config.markers,
          alignment_strategy: config.annotator_options.alignment_strategy.new(normalized_cleaned_body),
          options:            config.annotator_options.to_h,
        )
        toggled.chomp! if missing_newline?
        toggled
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
        @evaluated ||= !!SeeingIsBelieving.call(
          normalized_cleaned_body,
          config.lib_options.merge(event_handler: record_exit_events)
        )
        self
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
