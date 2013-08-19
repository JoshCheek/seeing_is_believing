require 'seeing_is_believing/parser_helpers'

class SeeingIsBelieving
  class Binary
    module RewriteComments
      def self.call(code, &mapping)
        buffer, parser, rewriter = ParserHelpers.initialize_parser code, 'rewrite_comments'
        ast, comments  = parser.parse_with_comments buffer

        comments.each do |comment|
          next unless comment.type == :inline
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

          # get results
          new_whitespace, new_comment = mapping.call(comment.location.line,
                                                     line,
                                                     preceeding_whitespace,
                                                     comment.text)

          # update code
          rewriter.replace preceeding_whitespace_range, new_whitespace
          rewriter.replace comment.location.expression, new_comment
        end

        rewriter.process
      end
    end
  end
end
