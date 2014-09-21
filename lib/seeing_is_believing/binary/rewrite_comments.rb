require 'seeing_is_believing/code'

class SeeingIsBelieving
  class Binary
    module RewriteComments
      def self.call(code, &mapping)
        code = Code.new(code)
        code.inline_comments.each do |comment|
          new_whitespace, new_comment = mapping.call comment
          code.rewriter.replace comment.whitespace_range, new_whitespace
          code.rewriter.replace comment.comment_range,    new_comment
        end
        code.rewriter.process
      end
    end
  end
end
