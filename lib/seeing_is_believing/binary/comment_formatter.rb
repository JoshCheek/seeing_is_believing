class SeeingIsBelieving
  class Binary
    # not sure I like this name, it formats comments that
    # show results e.g. "# => [1, 2, 3]"
    #
    # line_length is the length of the line this comment is being appended to
    #
    # For examples of what the options are, and how they all fit together, see
    # spec/binary/comment_formatter_spec.rb
    class CommentFormatter
      def self.call(*args)
        new(*args).call
      end

      def initialize(line_length, separator, result, options)
       self.line_length = line_length
       self.separator   = separator
       self.result      = result.gsub "\n", '\n'
       self.options     = options
      end

      def call
        @formatted ||= begin
          formatted = truncate "#{separator}#{result}", max_result_length
          formatted = "#{' '*padding_length}#{formatted}"
          formatted = truncate formatted, max_line_length
          formatted = '' unless formatted.sub(/^ */, '').start_with? separator
          formatted
        end
      end

      private

      attr_accessor :line_length, :separator, :result, :options

      def max_line_length
        length = options.fetch(:max_line_length, Float::INFINITY) - line_length
        length = 0 if length < 0
        length
      end

      def max_result_length
        options.fetch :max_result_length, Float::INFINITY
      end

      def padding_length
        padding_length = options.fetch(:pad_to, 0) - line_length
        padding_length = 0 if padding_length < 0
        padding_length
      end

      def truncate(string, length)
        return string if string.size <= length
        ellipsify string.slice(0, length)
      end

      def ellipsify(string)
        string.sub(/.{0,3}$/) { |last_chars| '.' * last_chars.size }
      end
    end
  end
end
