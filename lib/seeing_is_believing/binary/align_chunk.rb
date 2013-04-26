class SeeingIsBelieving
  class Binary
    class AlignChunk
      attr_accessor :body, :start_line, :end_line

      def initialize(body, start_line, end_line)
        self.body, self.start_line, self.end_line = body, start_line, end_line
      end

      # max line length of the the chunk (newline separated sections of code exempting comments) + 2 spaces for padding
      def line_length_for(line_number)
        line_lengths[line_number]
      end

      def line_lengths
        @line_lengths ||= Hash[
          body.each_line
              .map(&:chomp)
              .map.with_index(1) { |line, index| [line, index] }
              .take_while        { |line, index| not start_of_data_segment? line }
              .select            { |line, index| not SyntaxAnalyzer.begins_multiline_comment?(line) .. SyntaxAnalyzer.ends_multiline_comment?(line ) }
              .reject            { |line, index| SyntaxAnalyzer.ends_in_comment? line }
              .slice_before      { |line, index| line == '' }
              .map { |slice|
                max_chunk_length = 2 + slice.select { |line, index| start_line <= index && index <= end_line }
                                            .map { |line, index| line.length }
                                            .max
                slice.map { |line, index| [index, max_chunk_length] }
              }
              .flatten(1)
        ]
      end

      def start_of_data_segment?(line)
        SyntaxAnalyzer.begins_data_segment?(line.chomp)
      end
    end
  end
end
