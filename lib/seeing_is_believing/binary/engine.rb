require 'seeing_is_believing/binary/remove_annotations'
require 'seeing_is_believing/code'


class SeeingIsBelieving
  module Binary
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

      private

      attr_accessor :options

      # if body.end_with? "\n"
      #   predicates[:appended_newline] = false
      #   body_with_nl                  = body
      # else
      #   predicates[:appended_newline] = true
      #   body_with_nl                  = body + "\n"
      # end
      # attributes[:prepared_body]        = annotator.prepare_body(body_with_nl, marker_regexes)

    end
  end
end
