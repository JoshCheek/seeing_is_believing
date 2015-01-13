require 'seeing_is_believing/binary/remove_annotations'
require 'seeing_is_believing/code'

# From options, it uses:
#   body
#   filename
#   lib_options
#   annotator
#   marker_regexes     (entirely for annotator)
#   annotator_options
# Should be able to do this job with just:
#   body
#   filename
#   prepare_body(body)       <-- uhm, what's this for again?
#   evaluate(prepared_body)
#   annotate(body)

class SeeingIsBelieving
  module Binary
    class MustEvaluateFirst < SeeingIsBelievingError
      def initialize(method)
        super "Cannot call #{method} on engine until it has evaluated the program."
      end
    end

    class Engine
      def initialize(options)
        self.options = options
      end

      def missing_newline?
        @missing_newline ||= !options.body.end_with?("\n")
      end

      def syntax_error?
        syntax.invalid?
      end

      def syntax_error_message
        return "" if syntax.valid?
        "#{syntax.line_number}: #{syntax.error_message}"
      end

      def prepared_body
        @prepared_body ||= begin
          body_with_nl = options.body
          body_with_nl += "\n" if missing_newline?
          options.annotator.prepare_body body_with_nl, options.marker_regexes
        end
      end

      def cleaned_body
        @cleaned_body ||= begin
          cleaned_body = RemoveAnnotations.call prepared_body, true, options.marker_regexes
          cleaned_body.chomp! if missing_newline?
          cleaned_body
        end
      end

      def evaluate!
        return if @evaluate
        @evaluated = true
        @timed_out = false
        @results   = SeeingIsBelieving.call prepared_body, options.lib_options
      rescue Timeout::Error
        @timed_out = true
      ensure return self
      end

      def results
        @results || raise(MustEvaluateFirst.new __method__)
      end

      def timed_out?
        @evaluated || raise(MustEvaluateFirst.new __method__)
        @timed_out
      end

      # TODO: Annoying debugger stuff from annotators can move up to here
      # or maybe debugging goes to stderr, and we still print this anyway?
      def annotated_body
        @annotated_body ||= begin
          @evaluated || raise(MustEvaluateFirst.new __method__)
          annotated = options.annotator.call prepared_body,
                                             results,
                                             options.annotator_options
          annotated.chomp! if missing_newline?
          annotated
        end
      end

      def unexpected_exception
        @evaluated || raise(MustEvaluateFirst.new __method__)
        @unexpected_exception
      end

      def unexpected_exception?
        @evaluated || raise(MustEvaluateFirst.new __method__)
        !!unexpected_exception
      end

      private

      attr_accessor :options

      def code
        @code ||= Code.new(prepared_body, options.filename)
      end

      def syntax
        code.syntax
      end
    end
  end
end
