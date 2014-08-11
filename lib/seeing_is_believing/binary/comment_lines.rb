require 'seeing_is_believing/binary/commentable_lines'

class SeeingIsBelieving
  # spec/binary/comment_lines_spec.rb
  class Binary

    # takes a body and a block
    # passes the block the line
    # the block returns the comment to add at the end of it
    class CommentLines
      def self.call(code, &commenter)
        new(code, &commenter).call
      end

      def initialize(code, &commenter)
        self.code, self.commenter = code, commenter
      end

      def call
        @call ||= begin
          commentable_lines = CommentableLines.new code
          commentable_lines.call.each do |line_number, (index_of_newline, col)|
            first_index  = last_index = index_of_newline
            first_index -= 1 while first_index > 0 && code[first_index-1] != "\n"
            comment_text = commenter.call code[first_index...last_index], line_number
            range        = Parser::Source::Range.new(commentable_lines.buffer, first_index, last_index)
            commentable_lines.rewriter.insert_after range, comment_text
          end
          commentable_lines.rewriter.process
        end
      end

      private

      attr_accessor :code, :commenter
    end
  end
end
