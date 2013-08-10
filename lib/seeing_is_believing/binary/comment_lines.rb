require 'parser/current'

# CommentLines
#   takes a body and a block
#   passes the block the line
#   the block returns the comment to add at the end of it
#
# This class will get hit by the heredoc issue
# but it won't matter, because it's only used by AddAnnotations
# which won't have any result on that line
# Eventually, Parser should have this accounted for,
# and it will magically fix itself
class SeeingIsBelieving
  class Binary
    class CommentLines
      def self.call(code, &commenter)
        new(code, &commenter).call
      end

      def initialize(code, &commenter)
        self.code, self.commenter = code, commenter
      end

      # can't comment when there is already a comment
      def remove_lines_ending_in_comments(comments, lines_and_indexes)
        comments.each do |comment|
          if comment.type == :inline
            lines_and_indexes.delete comment.location.line
          else
            begin_pos = comment.location.expression.begin_pos
            end_pos   = comment.location.expression.end_pos
            range     = begin_pos...end_pos
            lines_and_indexes.select { |line_number, index_of_newline| range.include? index_of_newline }
                             .each   { |line_number, index_of_newline| lines_and_indexes.delete line_number }
          end
        end
      end

      # can't have a comment between the escape and the newline
      def remove_lines_whose_newline_is_escaped(lines_and_indexes)
        # TODO: will this -1 be a problem if there are empty lines at the top of the file?
        lines_and_indexes.select { |line_number, index_of_newline| code[index_of_newline-1] == '\\' }
                         .each   { |line_number, index_of_newline| lines_and_indexes.delete line_number }
      end

      # can't add a comment if inside a string/regex/etc
      def remove_lines_inside_of_strings_and_things(ast, lines_and_indexes)
        invalid_boundaries = ranges_of_atomic_expressions ast, []
        invalid_boundaries.each do |invalid_boundary|
          lines_and_indexes.select { |line_number, index_of_newline| invalid_boundary.include? index_of_newline }
                           .each   { |line_number, index_of_newline| lines_and_indexes.delete line_number }
        end
      end

      def call
        @call ||= begin
          buffer, parser, root, comments, rewriter = parse(code)
          lines_and_indexes = line_nums_to_last_index_on_line(buffer, code)
          remove_lines_whose_newline_is_escaped(lines_and_indexes)
          remove_lines_ending_in_comments(comments, lines_and_indexes)
          remove_lines_inside_of_strings_and_things(root, lines_and_indexes)
          add_comments(rewriter, buffer, code, lines_and_indexes, &commenter)
          rewriter.process
        end
      end

      def add_comments(rewriter, buffer, code, lines_and_indexes, &commenter)
        lines_and_indexes.each do |line_number, index_of_newline|
          first_index  = last_index = index_of_newline
          first_index -= 1 while first_index > 0 && code[first_index-1] != "\n"
          comment_text = commenter.call code[first_index...last_index], line_number
          range        = Parser::Source::Range.new(buffer, first_index, last_index)
          rewriter.insert_after range, comment_text
        end
      end

      private

      attr_accessor :code, :commenter

      def ranges_of_atomic_expressions(ast, found_ranges)
        return found_ranges unless ast.kind_of? ::AST::Node
        case ast.type
        when :dstr, :str, :xstr, :regexp
          begin_pos = ast.location.expression.begin.begin_pos
          end_pos   = ast.location.expression.end.end_pos
          found_ranges << (begin_pos...end_pos)
        else
          ast.children.each { |child| ranges_of_atomic_expressions child, found_ranges }
        end
        found_ranges
      end

      def parse(code)
        buffer = Parser::Source::Buffer.new("strip_comments").tap { |b| b.source = code }
        parser = Parser::CurrentRuby.new
        rewriter = Parser::Source::Rewriter.new(buffer)
        root, comments = parser.parse_with_comments(buffer)
        [buffer, parser, root, comments, rewriter]
      end

      def line_nums_to_last_index_on_line(buffer, code)
        lines_and_indexes = code.each_char
                                .with_index
                                .select { |char, index| char == "\n" } # <-- is this okay? what about other OSes?
                                .each_with_object(Hash.new) do |(_, index), hash|
                                  line, col = buffer.decompose_position index
                                  hash[line] = index
                                end
        # account for the fact that the last line wouldn't have been found above if it doesn't end in a newline
        if code[code.size-1] != "\n"
          line, col = buffer.decompose_position code.size
          lines_and_indexes[line] = code.size
        end

        lines_and_indexes
      end


    end
  end
end
