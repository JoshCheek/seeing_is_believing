class SeeingIsBelieving
  module Binary
    class AnnotateEveryLine
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
          require 'seeing_is_believing/binary/format_comment'
          exception_text = @options[:markers][:exception][:prefix]
          value_text     = @options[:markers][:value][:prefix]

          alignment_strategy = @options[:alignment_strategy].new(@body)
          exception_lineno   = @results.has_exception? ? @results.exception.line_number : -1
          new_body = CommentLines.call @body do |line, line_number|
            options = @options.merge pad_to: alignment_strategy.line_length_for(line_number)
            if exception_lineno == line_number
              result = sprintf "%s: %s", @results.exception.class_name, @results.exception.message.gsub("\n", '\n')
              FormatComment.call(line.size, exception_text, result, options)
            elsif @results[line_number].any?
              result  = @results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              FormatComment.call(line.size, value_text, result, options)
            else
              ''
            end
          end

          require 'seeing_is_believing/binary/annotate_end_of_file'
          AnnotateEndOfFile.add_stdout_stderr_and_exceptions_to new_body, @results, @options

          new_body
        end
      end
    end
  end
end
