class SeeingIsBelieving
  class Binary
    class AlignAll
      attr_accessor :body, :start_line, :end_line

      def initialize(body, start_line, end_line)
        self.body, self.start_line, self.end_line = body, start_line, end_line
      end

      # max line length of the lines to output (exempting comments) + 2 spaces for padding
      def line_length_for(line_number)
        @max_source_line_length ||= 2 + body.each_line
                                            .map(&:chomp)
                                            .select.with_index(1) { |line, index| start_line <= index && index <= end_line }
                                            .take_while { |line| not start_of_data_segment? line }
                                            .select { |line| not SyntaxAnalyzer.begins_multiline_comment?(line) .. SyntaxAnalyzer.ends_multiline_comment?(line ) }
                                            .reject { |line| SyntaxAnalyzer.ends_in_comment? line }
                                            .map(&:length)
                                            .concat([0])
                                            .max
      end

      def start_of_data_segment?(line)
        SyntaxAnalyzer.begins_data_segment?(line.chomp)
      end
    end
  end
end
