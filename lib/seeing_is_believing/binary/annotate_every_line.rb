class SeeingIsBelieving
  module Binary
    class AnnotateEveryLine
      def self.prepare_body(uncleaned_body, marker_regexes)
        require 'seeing_is_believing/binary/remove_annotations'
        RemoveAnnotations.call uncleaned_body, true, marker_regexes
      end

      def self.expression_wrapper(markers, marker_regexes)
        require 'seeing_is_believing/inspect_expressions'
        InspectExpressions
      end

      def self.call(body, results, options)
        new(body, results, options).call
      end

      def initialize(body, results, options={})
        @options = options
        @body    = body
        @results = results
      end

      def call
        @new_body ||= begin
          require 'seeing_is_believing/binary/comment_lines'
          require 'seeing_is_believing/binary/comment_formatter'

          alignment_strategy = @options[:alignment_strategy].new(@body)
          exception_lineno   = @results.has_exception? ? @results.exception.line_number : -1
          new_body = CommentLines.call @body do |line, line_number|
            options = @options.merge pad_to: alignment_strategy.line_length_for(line_number)
            if exception_lineno == line_number
              result = sprintf "%s: %s", @results.exception.class_name, @results.exception.message.gsub("\n", '\n')
              CommentFormatter.call(line.size, exception_marker, result, options)
            elsif @results[line_number].any?
              result  = @results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              CommentFormatter.call(line.size, value_marker, result, options)
            else
              ''
            end
          end

          require 'seeing_is_believing/binary/annotate_end_of_file'
          AnnotateEndOfFile.add_stdout_stderr_and_exceptions_to new_body, @results, @options

          # What's w/ this debugger? maybe this should move higher?
          @options.fetch(:debugger).context "OUTPUT"
          new_body
        end
      end

      private

      def value_marker
        @value_marker ||= @options.fetch(:markers).fetch(:value)
      end

      def exception_marker
        @xnextline_marker ||= @options.fetch(:markers).fetch(:exception)
      end
    end
  end
end
