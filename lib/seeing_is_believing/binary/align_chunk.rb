require 'seeing_is_believing/binary/commentable_lines'

class SeeingIsBelieving
  module Binary
    class AlignChunk
      def initialize(body)
        self.body = body
      end

      # max line length of the the chunk (newline separated sections of code exempting comments) + 2 spaces for padding
      def line_length_for(line_number)
        line_lengths.fetch line_number, 0
      end

      private

      attr_accessor :body

      def line_lengths
        @line_lengths ||= begin
          # sheesh, I need like Hash#map_values or something
          line_nums_to_cols = Hash.[] \
            CommentableLines.call(body)
                            .map { |line_num, (file_index, col_index)|
                              [line_num, col_index-amount_of_preceding_whitespace(file_index)]
                            }

          Hash.[] \
            line_nums_to_cols
              .keys
              .sort
              .slice_before { |line_number| line_nums_to_cols[line_number].zero?  }
              .flat_map { |slice|
                max_chunk_length = 2 + slice.map { |line_num| line_nums_to_cols[line_num] }.max
                slice.map { |line_number| [line_number, max_chunk_length] }
              }
        end
      end

      def amount_of_preceding_whitespace(index_of_trailing_newline)
        index = index_of_trailing_newline - 1
        index -= 1 while 0 <= index && body[index] !~ /[\S\n]/
        index_of_trailing_newline - index - 1
      end
    end
  end
end
