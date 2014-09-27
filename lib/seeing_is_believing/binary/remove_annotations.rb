require 'seeing_is_believing/binary'         # Defines the regexes to locate the markers
require 'seeing_is_believing/parser_helpers' # We have to parse the file to find the comments

class SeeingIsBelieving
  module Binary
    # TODO: might be here that we hit the issue where
    # you sometimes have to run it 2x to get it to correctly reset whitespace
    # should wipe out the full_range rather than just the comment_range
    class RemoveAnnotations
      def self.call(code, should_clean_values, markers)
        new(code, should_clean_values, markers).call
      end

      def initialize(code, should_clean_values, markers)
        self.should_clean_values = should_clean_values
        self.code                = code
        self.markers             = markers # TECHNICALLY THESE ARE REGEXES RIGHT NOW
      end

      def call
        code_obj         = Code.new(code, 'strip_comments')
        removed_comments = {result: [], exception: [], stdout: [], stderr: [], nextline: []}

        comment_chunks = code_obj
          .inline_comments
          .map { |c|
            annotation = c.text[value_regex] || c.text[exception_regex] || c.text[stdout_regex] || c.text[stderr_regex]
            [annotation, c]
          }
          .slice_before { |annotation, comment| annotation }
          .select       { |(annotation, start), *| annotation }
          .map { |(annotation, start), *rest|
            prev = start
            [start, rest.map(&:last).take_while { |comment|
              _prev, prev = prev, comment
              _prev.line_number.next == comment.line_number &&
                start.text_col == comment.text_col          &&
                comment.whitespace_col.zero?                &&
                annotation.length <= comment.text[/#\s*/].length
            }]
          }

        comment_chunks.each do |comment, rest|
          removed_comments[:nextline].concat rest
          rest.each { |c| code_obj.rewriter.remove c.comment_range }

          case comment.text
          when value_regex
            next unless should_clean_values
            removed_comments[:result] << comment
            code_obj.rewriter.remove comment.comment_range
          when exception_regex
            removed_comments[:exception] << comment
            code_obj.rewriter.remove comment.comment_range
          when stdout_regex
            removed_comments[:stdout] << comment
            code_obj.rewriter.remove comment.comment_range
          when stderr_regex
            removed_comments[:stderr] << comment
            code_obj.rewriter.remove comment.comment_range
          else
            raise "This should be impossible! Something must be broken in the comment section above"
          end
        end

        remove_whitespace_preceding_comments(code_obj.buffer, code_obj.rewriter, removed_comments)
        code_obj.rewriter.process
      end

      private

      attr_accessor :code, :should_clean_values, :buffer, :markers

      def remove_whitespace_preceding_comments(buffer, rewriter, removed_comments)
        removed_comments[:result].each    { |comment| remove_whitespace_before comment.comment_range.begin_pos, buffer, rewriter, false }
        removed_comments[:exception].each { |comment| remove_whitespace_before comment.comment_range.begin_pos, buffer, rewriter, true  }
        removed_comments[:stdout].each    { |comment| remove_whitespace_before comment.comment_range.begin_pos, buffer, rewriter, true  }
        removed_comments[:stderr].each    { |comment| remove_whitespace_before comment.comment_range.begin_pos, buffer, rewriter, true  }
        removed_comments[:nextline].each  { |comment| remove_whitespace_before comment.comment_range.begin_pos, buffer, rewriter, true  }
      end

      # any whitespace before the index (on the same line) will be removed
      # if the preceding whitespace is at the beginning of the line, the newline will be removed
      # if there is a newline before all of that, and remove_preceding_newline is true, it will be removed as well
      def remove_whitespace_before(index, buffer, rewriter, remove_preceding_newline)
        end_pos   = index
        begin_pos = end_pos - 1
        begin_pos -= 1 while code[begin_pos] =~ /\s/ && code[begin_pos] != "\n"
        begin_pos -= 1 if code[begin_pos] == "\n"
        begin_pos -= 1 if code[begin_pos] == "\n" && remove_preceding_newline
        return if begin_pos.next == end_pos
        rewriter.remove Parser::Source::Range.new(buffer, begin_pos.next, end_pos)
      end

      def value_regex
        markers.fetch(:value)
      end

      def exception_regex
        markers.fetch(:exception)
      end

      def stdout_regex
        markers.fetch(:stdout)
      end

      def stderr_regex
        markers.fetch(:stderr)
      end

      def nextline_regex
        markers.fetch(:nextline)
      end
    end
  end
end
