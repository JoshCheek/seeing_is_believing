require 'seeing_is_believing/binary/remove_annotations'
require 'seeing_is_believing/code'


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

      def code
        @code ||= Code.new(prepared_body, options.filename)
      end

      def syntax
        code.syntax
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
        @results, @timed_out, @unexpected_exception =
          evaluate_program(prepared_body, options.lib_options)
        @annotated_body = true
        @evaluated = true
      end

      def results
        @results || raise(MustEvaluateFirst.new __method__)
      end

      def timed_out?
        return @timed_out unless @timed_out.nil?
        raise MustEvaluateFirst.new __method__
      end

      def annotated_body
        @annotated_body || raise(MustEvaluateFirst.new __method__)
      end

      def unexpected_exception
        @evaluated || raise(MustEvaluateFirst.new __method__)
        @unexpected_exception
      end

      def unexpected_exception?
        @evaluated || raise(MustEvaluateFirst.new __method__)
        !unexpected_exception
      end

      private

      attr_accessor :options

      def evaluate_program(body, options)
        return SeeingIsBelieving.call(body, options), false, nil
      rescue Timeout::Error
        return nil, true, nil
      rescue Exception
        return nil, false, $!
      end


    end
  end
end
