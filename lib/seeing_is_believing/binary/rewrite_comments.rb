require 'seeing_is_believing/code'

class SeeingIsBelieving
  module Binary
    module RewriteComments
      def self.call(code, options={}, &mapping)
        code     = Code.new(code)
        comments = code.inline_comments
        buffer   = code.buffer

        comments.each do |comment|
          new_whitespace, new_comment = mapping.call comment
          code.rewriter.replace comment.whitespace_range, new_whitespace
          code.rewriter.replace comment.comment_range,    new_comment
        end

        line_begins = line_begins_for(buffer.source)
        options.fetch(:always_rewrite, []).each { |line_number|
          next if comments.any? { |c| c.line_number == line_number }

          # TODO: can this move down into Code?
          _, next_line_index = (line_begins.find { |ln, index| ln == line_number } || [nil, buffer.source.size.next])
          col  = 0
          col += 1 until col == next_line_index || buffer.source[next_line_index-2-col] == "\n"

          index   = next_line_index - 1
          range   = code.range_for(index, index)

          comment = Code::InlineComment.new line_number, # line_number,
                                            col,         # preceding_whitespace_range.column,
                                            "",          # preceding_whitespace,
                                            col,         # comment.location.column,
                                            "",          # comment.text,
                                            range,       # range_for(first_char, comment.location.expression.end_pos),
                                            range,       # preceding_whitespace_range,
                                            range        # comment.location.expression

          whitespace, body = mapping.call comment
          code.rewriter.insert_before range, "#{whitespace}#{body}"
        }

        code.rewriter.process
      end

      # TODO: Move down into the Code obj?
      # returns: [[lineno, index], ...]
      def self.line_begins_for(raw_code)
        # Copied from here https://github.com/whitequark/parser/blob/34c40479293bb9b5ba217039cf349111466d1f9a/lib/parser/source/buffer.rb#L213-227
        # I figured it's better to copy it than to violate encapsulation since this is private
        line_begins, index = [ [ 0, 0 ] ], 1

        raw_code.each_char do |char|
          if char == "\n"
            line_begins.unshift [ line_begins.length, index ]
          end

          index += 1
        end
        line_begins
      end
    end
  end
end
