class SeeingIsBelieving
  class Binary
    class AlignChunk
      attr_accessor :body, :start_line, :end_line

      def initialize(body, start_line, end_line)
        self.body, self.start_line, self.end_line = body, start_line, end_line
      end

      # max line length of the the chunk (newline separated sections of code exempting comments) + 2 spaces for padding
      def line_length_for(line_number)
        return 0 if line_number < start_line || end_line < line_number
        line_lengths[line_number]
      end

      def line_lengths
        @line_lengths ||= begin
          lines_and_indexes, * = CommentLines.new(body).commentable_lines
          Hash[lines_and_indexes
                 .keys # line_numbers
                 .sort
                 .slice_before { |line_number| lines_and_indexes[line_number].last.zero? }
                 .map { |slice|
                   max_chunk_length = 2 + slice.select { |line_num| start_line <= line_num && line_num <= end_line }
                                               .map    { |line_num| lines_and_indexes[line_num].last }
                                               .max
                   slice.map { |line_number| [line_number, max_chunk_length] }
                 }
                 .flatten(1)
          ]
        end
      end
    end
  end
end
