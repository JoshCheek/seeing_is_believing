class SeeingIsBelieving
  class Binary
    class CommentFormatter
      def self.call(*args)
        new(*args).call
      end

      attr_accessor :line, :separator, :result, :options

      def initialize(line, separator, result, options)
       self.line      = line
       self.separator = separator
       self.result    = result.gsub "\n", '\n'
       self.options   = options
      end

      def call
        formatted = truncate "#{separator}#{result}", result_length
        formatted = "#{' '*padding_length}#{formatted}"
        formatted = truncate formatted, line_length
        formatted = '' unless formatted.sub(/^ */, '').start_with? separator
        formatted
      end

      private

      def line_length
        length = options.fetch(:line_length, Float::INFINITY) - line.size
        length = 0 if length < 0
        length
      end

      def result_length
        options.fetch :result_length, Float::INFINITY
      end

      def padding_length
        padding_length = options.fetch(:pad_to, 0) - line.size
        padding_length = 0 if padding_length < 0
        padding_length
      end

      def truncate(string, length)
        return string if string.size <= length
        ellipsify string.slice(0, length)
      end

      def ellipsify(string)
        string.sub(/.{0,3}$/) { |last_chars| last_chars.gsub /./, '.' }
      end
    end
  end
end
