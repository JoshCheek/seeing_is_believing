require 'seeing_is_believing/parser_helpers'

class SeeingIsBelieving
  class Binary
    class FindComments
      Comment = Struct.new :line_number, :preceding_code, :whitespace, :comment, :whitespace_range, :comment_range

      # Exposed so that comments found here can be rewritten
      # Not super stoked about this, though. Maybe this initialization should happen up higher,
      # and it should be passed into here as well as to the rewriter?
      attr_reader :rewriter, :buffer

      def initialize(code)
        @buffer, parser, @rewriter = ParserHelpers.initialize_parser code, 'finding_comments'
        ast, @parser_comments = parser.parse_with_comments buffer
        @parser_comments.select! { |comment| comment.type == :inline }
      end

      def comments
        @comments ||= @parser_comments.map { |comment|
          # find whitespace
          last_char                   = comment.location.expression.begin_pos
          first_char                  = last_char
          first_char -= 1 while first_char > 0 && buffer.source[first_char-1] =~ /[ \t]/
          preceding_whitespace        = buffer.source[first_char...last_char]
          preceding_whitespace_range  = Parser::Source::Range.new buffer, first_char, last_char

          # find line
          last_char = first_char
          first_char -= 1 while first_char > 0 && buffer.source[first_char-1] !~ /[\r\n]/
          line = buffer.source[first_char...last_char]

          # build comment
          Comment.new comment.location.line,
                      line,
                      preceding_whitespace,
                      comment.text,
                      preceding_whitespace_range,
                      comment.location.expression
        }
      end
    end
  end
end
