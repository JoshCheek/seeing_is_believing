require 'seeing_is_believing/parser_helpers'

class SeeingIsBelieving
  class Binary
    class FindComments
      Comment = Struct.new :line_number, :code, :whitespace, :comment, :whitespace_range, :comment_range

      # Exposed so that comments found here can be rewritten
      # Not super stoked about this, though. Maybe this initialization should happen up higher,
      # and it should be passed into here as well as to the rewriter?
      attr_reader :rewriter

      def initialize(code)
        @code = code
        @buffer, parser, @rewriter = ParserHelpers.initialize_parser code, 'finding_comments'
        ast, @all_comments = parser.parse_with_comments buffer
      end

      def comments
        @comments ||= @all_comments.select { |comment| comment.type == :inline }
                                   .map { |comment|
                                     # find whitespace
                                     last_char                   = comment.location.expression.begin_pos
                                     first_char                  = last_char
                                     first_char -= 1 while first_char > 0 && buffer.source[first_char-1] =~ /[ \t]/
                                     preceeding_whitespace       = buffer.source[first_char...last_char]
                                     preceeding_whitespace_range = Parser::Source::Range.new buffer, first_char, last_char

                                     # find line
                                     last_char = first_char
                                     first_char -= 1 while first_char > 0 && buffer.source[first_char-1] !~ /[\r\n]/
                                     line = buffer.source[first_char...last_char]

                                     Comment.new comment.location.line,
                                                 line,
                                                 preceeding_whitespace,
                                                 comment.text,
                                                 preceeding_whitespace_range,
                                                 comment.location.expression
                                   }
      end

      private

      attr_reader :code, :buffer, :all_comments
    end
  end
end
