class SeeingIsBelieving
  class Binary
    class LineFormatter
      attr_accessor :line, :separator, :result, :options

      def initialize(line, separator, result, options)
       self.line      = line
       self.separator = separator
       self.result    = result.gsub "\n", '\n'
       self.options   = options
      end

      def call
        return line unless sep_plus_result.start_with? separator
        return line unless formatted_line.start_with? "#{line_with_padding}#{separator}"
        formatted_line
      end

      private

      def line_length
        options.fetch :line_length, Float::INFINITY
      end

      def result_length
        options.fetch :result_length, Float::INFINITY
      end

      def sep_plus_result
        @sep_plus_result ||= truncate "#{separator}#{result}", result_length
      end

      def formatted_line
        @formatted_line ||= truncate "#{line_with_padding}#{sep_plus_result}", line_length
      end

      def line_with_padding
        "%-#{options[:source_length]}s" % line
      end

      def truncate(string, length)
        return string if string.size <= length
        string.slice(0, length).sub(/.{0,3}$/) { |last_chars| last_chars.gsub /./, '.' }
      end
    end
  end
end
