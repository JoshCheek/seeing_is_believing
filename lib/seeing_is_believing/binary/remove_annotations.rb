require 'seeing_is_believing/binary' # Defines the regexes to locate the markers
require 'seeing_is_believing/code'   # We have to parse the file to find the comments

class SeeingIsBelieving
  module Binary
    class RemoveAnnotations
      def self.call(raw_code, should_clean_values, markers)
        new(raw_code, should_clean_values, markers).call
      end

      def initialize(raw_code, should_clean_values, markers)
        self.should_clean_values = should_clean_values
        self.raw_code            = raw_code
        self.markers             = markers # TECHNICALLY THESE ARE REGEXES RIGHT NOW
        self.code                = Code.new(raw_code, 'strip_comments')
      end

      def call
        annotation_chunks_in(code).each do |comment, rest|
          rest.each { |comment|
            code.rewriter.remove comment.comment_range
            remove_whitespace_before comment.comment_range.begin_pos, code.buffer, code.rewriter, false
          }

          case comment.text
          when value_regex
            next unless should_clean_values
            code.rewriter.remove comment.comment_range
            remove_whitespace_before comment.comment_range.begin_pos, code.buffer, code.rewriter, false
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

      attr_accessor :raw_code, :should_clean_values, :markers, :code

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
          .map { |comment| [ (comment.text[value_regex]     ||     # associates each comment to its annotation
                              comment.text[exception_regex] ||
                              comment.text[stdout_regex]    ||
                              comment.text[stderr_regex]
                             ),
                             comment]}
          .slice_before { |annotation, comment| annotation }       # annotations begin chunks
          .select       { |(annotation, start), *| annotation }    # discard chunks not beginning with an annotation (probably can only happens on first comment)
          .map { |(annotation, start), *rest|                      # end the chunk if the comment doesn't meet nextline criteria
            nextline_comments = []
            prev = start
            rest.each { |_, potential_nextline|
              break unless prev.line_number.next == potential_nextline.line_number &&
                             start.text_col == potential_nextline.text_col         &&
                             potential_nextline.whitespace_col.zero?               &&
                             annotation.length <= potential_nextline.text[/#\s*/].length
              prev = potential_nextline
              nextline_comments << potential_nextline
            }
            [start, nextline_comments]
          }
      end

      def value_regex
        markers.fetch(:value).fetch(:regex)
      end

      def exception_regex
        markers.fetch(:exception).fetch(:regex)
      end

      def stdout_regex
        markers.fetch(:stdout).fetch(:regex)
      end

      def stderr_regex
        markers.fetch(:stderr).fetch(:regex)
      end
    end
  end
end
