require 'seeing_is_believing/code'

class SeeingIsBelieving
  module Binary
    module RewriteComments
      def self.call(raw_code, options={}, &mapping)
        code          = Code.new(raw_code)
        comments      = code.inline_comments
        buffer        = code.buffer
        options       = options.dup
        extra_lines   = options.delete(:include_lines) || []
        raise ArgumentError, "Unknown options: #{options.inspect}" if options.any?

        # update existing comments
        comments.each do |comment|
          extra_lines.delete comment.line_number
          new_whitespace, new_comment = mapping.call comment
          code.rewriter.replace comment.whitespace_range, new_whitespace
          code.rewriter.replace comment.comment_range,    new_comment
        end

        # add additional comments
        extra_lines.each do |line_number|
          line_begin_col     = code.line_number_to_index(line_number)
          nextline_begin_col = code.line_number_to_index(line_number.next)
          nextline_begin_col -= 1 if raw_code[nextline_begin_col-1] == "\n"
          whitespace_col     = nextline_begin_col-1
          whitespace_col     -= 1 while line_begin_col < whitespace_col &&
                                        raw_code[whitespace_col] =~ /\s/
          whitespace_col += 1
          whitespace_range = code.range_for(whitespace_col, nextline_begin_col)
          comment_range = code.range_for(nextline_begin_col, nextline_begin_col)

          comment = Code::InlineComment.new \
            line_number,                                   # line_number
            whitespace_col-line_begin_col,                 # whitespace_col
            raw_code[whitespace_col...nextline_begin_col], # preceding_whitespace
            nextline_begin_col-line_begin_col,             # text_col
            "",                                            # text
            whitespace_range,                              # full_range
            whitespace_range,                              # whitespace_range
            comment_range                                  # comment_range

          whitespace, body = mapping.call comment
          code.rewriter.replace whitespace_range, "#{whitespace}#{body}"
        end

        # perform the rewrite
        code.rewriter.process
      end
    end
  end
end
