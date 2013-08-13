require 'seeing_is_believing/binary/commentable_lines'

class SeeingIsBelieving
  class Binary
    class AlignChunk
      def initialize(body, start_line, end_line)
        self.body, self.start_line, self.end_line = body, start_line, end_line
      end

      # max line length of the the chunk (newline separated sections of code exempting comments) + 2 spaces for padding
      def line_length_for(line_number)
        line_lengths.fetch line_number, 0
      end

      private

      attr_accessor :body, :start_line, :end_line

      def line_lengths
        @line_lengths ||= begin
          line_num_to_indexes = CommentableLines.new(body).call # {line_number => [index_in_file, index_in_col]}
          Hash[line_num_to_indexes
                 .keys
                 .sort
                 .slice_before { |line_number| line_num_to_indexes[line_number].last.zero? }
                 .map { |slice|
                   max_chunk_length = 2 + slice.select { |line_num| start_line <= line_num && line_num <= end_line }
                                               .map    { |line_num| line_num_to_indexes[line_num].last }
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
