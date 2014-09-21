class SeeingIsBelieving
  module Binary
    class AlignLine
      attr_accessor :body

      def initialize(body)
        self.body = body
      end

      # length of the line + 2 spaces for padding
      def line_length_for(line_number)
        line_lengths[line_number]
      end

      def line_lengths
        @line_lengths ||= Hash[ body.each_line
                                    .map(&:chomp)
                                    .each
                                    .with_index(1)
                                    .map { |line, index| [index, line.length+2] }
                              ]
      end
    end
  end
end
