require 'seeing_is_believing/binary' # Defines the regexes to locate the markers
require 'seeing_is_believing/code'   # We have to parse the file to find the comments

class SeeingIsBelieving
  module Binary
    class RemoveAnnotations
      def self.call(raw_code, remove_value_prefixes, markers)
        new(raw_code, remove_value_prefixes, markers).call
      end

      def initialize(raw_code, remove_value_prefixes, markers)
        self.remove_value_prefixes = remove_value_prefixes
        self.raw_code              = raw_code
        self.markers               = markers
        self.code                  = Code.new(raw_code, 'strip_comments')
      end

      def call
        annotation_chunks_in(code).each do |comment, rest|
          rest.each { |comment|
            code.rewriter.remove comment.comment_range
            remove_whitespace_before comment.comment_range.begin_pos, code.buffer, code.rewriter, false
          }

          case comment.text
          when value_regex
            if remove_value_prefixes
              code.rewriter.remove comment.comment_range
              remove_whitespace_before comment.comment_range.begin_pos, code.buffer, code.rewriter, false
            else
              prefix = comment.text[value_regex].rstrip
              code.rewriter.replace comment.comment_range, prefix
            end
          when exception_regex
            code.rewriter.remove comment.comment_range
            remove_whitespace_before comment.comment_range.begin_pos, code.buffer, code.rewriter, true
          when stdout_regex
            code.rewriter.remove comment.comment_range
            remove_whitespace_before comment.comment_range.begin_pos, code.buffer, code.rewriter, true
          when stderr_regex
            code.rewriter.remove comment.comment_range
            remove_whitespace_before comment.comment_range.begin_pos, code.buffer, code.rewriter, true
          else
            raise "This should be impossible! Something must be broken in the comment section above"
          end
        end

        code.rewriter.process
      end

      private

      attr_accessor :raw_code, :remove_value_prefixes, :markers, :code

      # any whitespace before the index (on the same line) will be removed
      # if the preceding whitespace is at the beginning of the line, the newline will be removed
      # if there is a newline before all of that, and remove_preceding_newline is true, it will be removed as well
      def remove_whitespace_before(index, buffer, rewriter, remove_preceding_newline)
        end_pos   = index
        begin_pos = end_pos - 1
        begin_pos -= 1 while 0 <= begin_pos && raw_code[begin_pos] =~ /\s/ && raw_code[begin_pos] != "\n"
        begin_pos -= 1 if 0 <= begin_pos && raw_code[begin_pos] == "\n"
        begin_pos -= 1 if remove_preceding_newline && 0 <= begin_pos && raw_code[begin_pos] == "\n"
        return if begin_pos.next == end_pos
        rewriter.remove code.range_for(begin_pos.next, end_pos)
      end

      def annotation_chunks_in(code)
        code
          .inline_comments
          .map { |comment| # associate each annotation to its comment
            annotation = comment.text[value_regex]     ||
                         comment.text[exception_regex] ||
                         comment.text[stdout_regex]    ||
                         comment.text[stderr_regex]
            [annotation, comment]
          }
          .slice_before { |annotation, comment| annotation }    # annotations begin chunks
          .select       { |(annotation, start), *| annotation } # discard chunks not beginning with an annotation (probably can only happens on first comment)
          .map { |(annotation, start), *rest|                   # end the chunk if the comment doesn't meet nextline criteria
            nextline_comments = []
            prev              = start
            rest.each { |_, potential_nextline|
              sequential                   = (prev.line_number.next == potential_nextline.line_number)
              vertically_aligned           = start.text_col == potential_nextline.text_col
              only_preceded_by_whitespace  = potential_nextline.whitespace_col.zero?
              indention_matches_annotation = annotation.length <= potential_nextline.text[/#\s*/].length
              break unless sequential && vertically_aligned && only_preceded_by_whitespace && indention_matches_annotation
              nextline_comments << potential_nextline
              prev = potential_nextline
            }
            [start, nextline_comments]
          }
      end

      def value_regex
        @value_regex ||= markers.fetch(:value).fetch(:regex)
      end

      def exception_regex
        @exception_regex ||= markers.fetch(:exception).fetch(:regex)
      end

      def stdout_regex
        @stdout_regex ||= markers.fetch(:stdout).fetch(:regex)
      end

      def stderr_regex
        @stderr_regex ||= markers.fetch(:stderr).fetch(:regex)
      end
    end
  end
end
