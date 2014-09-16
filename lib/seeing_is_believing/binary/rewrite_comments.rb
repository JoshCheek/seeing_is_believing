require 'seeing_is_believing/binary/find_comments'

class SeeingIsBelieving
  class Binary
    module RewriteComments
      def self.call(code, &mapping)
        finder   = FindComments.new(code)
        rewriter = finder.rewriter
        finder.comments.each do |comment|
          new_whitespace, new_comment = mapping.call \
            comment.line_number, comment.code, comment.whitespace, comment.comment

          rewriter.replace comment.whitespace_range, new_whitespace
          rewriter.replace comment.comment_range,    new_comment
        end
        rewriter.process
      end
    end
  end
end
