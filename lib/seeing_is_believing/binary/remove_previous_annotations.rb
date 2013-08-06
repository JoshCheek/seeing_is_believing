require 'seeing_is_believing/remove_inline_comments'

class SeeingIsBelieving
  class Binary
    class RemovePreviousAnnotations
      def self.call(code)
        new(code).call
      end

      def initialize(code)
        self.code     = code
        self.comments = { result:    [],
                          exception: [],
                          stdout:    [],
                          stderr:    [],
                        }
      end

      def call
        RemoveInlineComments.call code, additional_rewrites: remove_whitespace_preceeding_comments do |comment|
          if    comment.text[/\A#\s*=>/] then comments[:result]    << comment; true
          elsif comment.text[/\A#\s*~>/] then comments[:exception] << comment; true
          elsif comment.text[/\A#\s*>>/] then comments[:stdout]    << comment; true
          elsif comment.text[/\A#\s*!>/] then comments[:stderr]    << comment; true
          else                                                                 false
          end
        end
      end

      private

      attr_accessor :code, :comments

      def remove_whitespace_preceeding_comments
        lambda do |buffer, rewriter|
          comments[:result].each    { |comment| remove_whitespace_before comment.location.expression.begin_pos, buffer, rewriter, false }
          comments[:exception].each { |comment| remove_whitespace_before comment.location.expression.begin_pos, buffer, rewriter, true  }
          comments[:stdout].each    { |comment| remove_whitespace_before comment.location.expression.begin_pos, buffer, rewriter, true  }
          comments[:stderr].each    { |comment| remove_whitespace_before comment.location.expression.begin_pos, buffer, rewriter, true  }
        end
      end

      # any whitespace before the index (on the same line) will be removed
      # if the preceeding whitespace is at the beginning of the line, the newline will be removed
      # if there is a newline before all of that, and remove_preceeding_newline is true, it will be removed as well
      def remove_whitespace_before(index, buffer, rewriter, remove_preceeding_newline)
        end_pos   = index
        begin_pos = end_pos - 1
        begin_pos -= 1 while code[begin_pos] =~ /\s/ && code[begin_pos] != "\n"
        begin_pos -= 1 if code[begin_pos] == "\n"
        begin_pos -= 1 if code[begin_pos] == "\n" && remove_preceeding_newline
        return if begin_pos.next == end_pos
        rewriter.remove Parser::Source::Range.new(buffer, begin_pos.next, end_pos)
      end

      # returns comments in groups that are on consecutive lines
      def adjacent_comments(comments, buffer)
        comments          = comments.sort_by { |comment| comment.location.begin_pos }
        current_chunk     = 0
        last_line_seen    = -100
        chunks_to_comment = comments.chunk do |comment|
          line, col = buffer.decompose_position comment.location.begin_pos
          if last_line_seen.next == line
            last_line_seen = line
            current_chunk
          else
            last_line_seen = line
            current_chunk += 1
          end
        end
        chunks_to_comment.map &:last
      end
    end
  end
end
