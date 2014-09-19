class SeeingIsBelieving
  class Binary
    class AnnotateEveryLine
      def self.prepare_body(uncleaned_body)
        require 'seeing_is_believing/binary/remove_annotations'
        RemoveAnnotations.call uncleaned_body, true
      end

      def self.expression_wrapper
        InspectExpressions
      end

      def initialize(body, results, options={})
        self.options = options
        self.body    = body
        self.results = results
      end

      def call
        @new_body ||= begin
          new_body = body_with_everything_annotated

          require 'seeing_is_believing/binary/annotate_end_of_file'
          AnnotateEndOfFile.add_stdout_stderr_and_exceptions_to new_body, results, options

          # What's w/ this debugger? maybe this should move higher?
          options[:debugger].context "OUTPUT"
          new_body
        end
      end

      private

      attr_accessor :results, :body, :options, :alignment_strategy

      def body_with_everything_annotated
        require 'seeing_is_believing/binary/comment_lines'
        require 'seeing_is_believing/binary/comment_formatter'
        require 'seeing_is_believing/binary' # defines the markers
        alignment_strategy = options[:alignment_strategy].new(body)
        exception_lineno   = results.has_exception? ? results.exception.line_number : -1
        CommentLines.call body do |line, line_number|
          options = options().merge pad_to: alignment_strategy.line_length_for(line_number)
          if exception_lineno == line_number
            result = sprintf "%s: %s", results.exception.class_name, results.exception.message.gsub("\n", '\n')
            CommentFormatter.call(line.size, EXCEPTION_MARKER, result, options)
          elsif results[line_number].any?
            result  = results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
            CommentFormatter.call(line.size, VALUE_MARKER, result, options)
          else
            ''
          end
        end
      end
    end
  end
end
