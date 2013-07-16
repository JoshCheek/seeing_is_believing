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
                          stderr:    []
                        }
      end

      def call
        RemoveInlineComments.call code, additional_rewrites: remove_whitespace_preceeding_comments do |comment|
          if    comment.text[/\A#\s*=>/]    then comments[:result]    << comment; true
          elsif comment.text[/\A#\s*~>/]    then comments[:exception] << comment; true
          elsif comment.text[/\A\s*#\s*>>/] then comments[:stdout]    << comment; true
          elsif comment.text[/\A\s*#\s*!>/] then comments[:stderr]    << comment; true
          else                                                                    false
          end
        end
      end

      private

      attr_accessor :code, :comments

      def remove_whitespace_preceeding_comments
        lambda do |buffer, rewriter|
          comments[:result].each    { |comment| remove_whitespace_before buffer, rewriter, comment.location.begin_pos, false }
          comments[:exception].each { |comment| remove_whitespace_before buffer, rewriter, comment.location.begin_pos, false }
          comments[:stdout].each    { |comment| remove_whitespace_before buffer, rewriter, comment.location.begin_pos, true  }
          comments[:stderr].each    { |comment| remove_whitespace_before buffer, rewriter, comment.location.begin_pos, true  }

          remove_preceeding_newline buffer, rewriter, comments[:stdout]
          remove_preceeding_newline buffer, rewriter, comments[:stderr]
        end
      end

      def remove_preceeding_newline(buffer, rewriter, comments)
        return if comments.empty?
        first_comment = comments.min_by { |comment| comment.location.begin_pos }
        end_pos       = first_comment.location.begin_pos
        end_pos -= 1 while 0 <= end_pos && code[end_pos] != "\n"
        begin_pos     = end_pos - 1
        return if begin_pos < 0 || code[begin_pos] != "\n"
        rewriter.remove Parser::Source::Range.new(buffer, begin_pos, end_pos)
      end

      def remove_whitespace_before(buffer, rewriter, index, include_newlines)
        end_pos   = index
        begin_pos = end_pos - 1
        begin_pos -= 1 while code[begin_pos] =~ /\s/ && code[begin_pos] != "\n"
        begin_pos -= 1 if include_newlines && code[begin_pos] == "\n"
        return if begin_pos.next == end_pos
        rewriter.remove Parser::Source::Range.new(buffer, begin_pos.next, end_pos)
      end
    end
  end
end
