require 'seeing_is_believing/code'
require 'seeing_is_believing/binary/commentable_lines'

class SeeingIsBelieving
  module Binary
    # can this be joined into CommentLines?
    # that one yields every commentable line, this one just lines which have comments
    # what they yield is a little different, too, but their algorithms and domain are very similar
    module RewriteComments
      Options = HashStruct.anon do
        attribute(:include_lines) { [] }
      end

      def self.call(raw_code, options={}, &mapping)
        code        = Code.new(raw_code)
        comments    = code.inline_comments
        extra_lines = Options.new(options).include_lines

        # update existing comments
        comments.each do |comment|
          new_whitespace, new_comment = mapping.call comment
          code.rewriter.replace comment.whitespace_range, new_whitespace
          code.rewriter.replace comment.comment_range,    new_comment
        end

        # remove extra lines that are handled / uncommentable
        comments.each { |c| extra_lines.delete c.line_number }
        commentable_linenums = CommentableLines.call(code.raw).map { |linenum, *| linenum }
        extra_lines.select! { |linenum| commentable_linenums.include? linenum }

        # add additional comments
        extra_lines.each do |line_number|
          line_begin_col     = code.linenum_to_index(line_number)
          nextline_begin_col = code.linenum_to_index(line_number.next)
          nextline_begin_col -= 1 if code.raw[nextline_begin_col-1] == "\n"
          whitespace_col     = nextline_begin_col-1
          whitespace_col     -= 1 while line_begin_col < whitespace_col &&
                                        code.raw[whitespace_col] =~ /\s/
          whitespace_col += 1
          whitespace_range = code.range_for(whitespace_col, nextline_begin_col)
          comment_range = code.range_for(nextline_begin_col, nextline_begin_col)

          comment = Code::InlineComment.new \
            line_number:      line_number,
            whitespace_col:   whitespace_col-line_begin_col,
            whitespace:       code.raw[whitespace_col...nextline_begin_col]||"",
            text_col:         nextline_begin_col-line_begin_col,
            text:             "",
            full_range:       whitespace_range,
            whitespace_range: whitespace_range,
            comment_range:    comment_range

          whitespace, body = mapping.call comment
          code.rewriter.replace whitespace_range, "#{whitespace}#{body}"
        end

        # perform the rewrite
        code.rewriter.process
      end
    end
  end
end
