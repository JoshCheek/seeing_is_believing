require 'seeing_is_believing/binary/commentable_lines'

class SeeingIsBelieving
  class Binary
    class AlignFile
      attr_accessor :body, :start_line, :end_line

      def initialize(body, start_line, end_line)
        self.body, self.start_line, self.end_line = body, start_line, end_line
      end

      # max line length of the lines to output (exempting comments) + 2 spaces for padding
      def line_length_for(line_number)
        @max_source_line_length ||= 2 + begin
          line_num_to_indexes = CommentableLines.new(body).call # {line_number => [index_in_file, index_in_col]}
          max_value = line_num_to_indexes
                           .select { |line_num, _| start_line <= line_num && line_num <= end_line }
                           .values
                           .map { |index, col| col }.max
          max_value || 0
        end
      end
    end
  end
end
