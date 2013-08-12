require 'parser/current'

# CommentLines
#   takes a body and a block
#   passes the block the line
#   the block returns the comment to add at the end of it
class SeeingIsBelieving
  class Binary
    class CommentLines
      def self.call(code, &commenter)
        new(code, &commenter).call
      end

      def initialize(code, &commenter)
        self.code, self.commenter = code, commenter
      end

      def call
        @call ||= begin
          add_comments_to commentable_lines
          rewriter.process
        end
      end

      def commentable_lines
        @commentable_lines ||= begin
          remove_lines_after_data_segment
          remove_lines_whose_newline_is_escaped
          remove_lines_ending_in_comments
          remove_lines_inside_of_strings_and_things
          line_nums_to_last_index_and_col
        end
      end

      private

      attr_accessor :code, :commenter

      def buffer
        @buffer ||= Parser::Source::Buffer.new("strip_comments").tap { |b| b.source = code }
      end

      def parser
        @parser ||= Parser::CurrentRuby.new
      end

      def rewriter
        @rewriter ||= Parser::Source::Rewriter.new(buffer)
      end

      def root
        parse!
        @root
      end

      def comments
        parse!
        @comments
      end

      def parse!
        return if @root
        @root, @comments = parser.parse_with_comments(buffer)
      end

      def line_nums_to_last_index_and_col
        @line_nums_to_last_index_and_col ||= begin
          lines_and_indexes = code.each_char
                                  .with_index
                                  .select { |char, index| char == "\n" } # <-- is this okay? what about other OSes?
                                  .each_with_object(Hash.new) do |(_, index), hash|
                                    line, col = buffer.decompose_position index
                                    hash[line] = [index, col]
                                  end
          if code[code.size-1] != "\n" # account for the fact that the last line wouldn't have been found above if it doesn't end in a newline
            line, col = buffer.decompose_position code.size
            lines_and_indexes[line] = [code.size, col]
          end
          lines_and_indexes
        end
      end

      def remove_lines_whose_newline_is_escaped
        line_nums_to_last_index_and_col.select { |line_number, (index_of_newline, col)| code[index_of_newline-1] == '\\' }
                                       .each   { |line_number, (index_of_newline, col)| line_nums_to_last_index_and_col.delete line_number }
      end

      def remove_lines_ending_in_comments
        comments.each do |comment|
          if comment.type == :inline
            line_nums_to_last_index_and_col.delete comment.location.line
          else
            begin_pos = comment.location.expression.begin_pos
            end_pos   = comment.location.expression.end_pos
            range     = begin_pos...end_pos
            line_nums_to_last_index_and_col.select { |line_number, (index_of_newline, col)| range.include? index_of_newline }
                                           .each   { |line_number, (index_of_newline, col)| line_nums_to_last_index_and_col.delete line_number }
          end
        end
      end

      def remove_lines_inside_of_strings_and_things
        invalid_boundaries = ranges_of_atomic_expressions root, []
        invalid_boundaries.each do |invalid_boundary|
          line_nums_to_last_index_and_col.select { |line_number, (index_of_newline, col)| invalid_boundary.include? index_of_newline }
                                         .each   { |line_number, (index_of_newline, col)| line_nums_to_last_index_and_col.delete line_number }
        end
      end

      def ranges_of_atomic_expressions(ast, found_ranges)
        return found_ranges unless ast.kind_of? ::AST::Node
        if no_comment_zone?(ast) && heredoc?(ast)
          begin_pos  = ast.location.expression.begin.begin_pos
          begin_pos += (ast.location.expression.source =~ /\n/).next
          end_pos    = ast.location.expression.end.end_pos.next
          found_ranges << (begin_pos...end_pos)
        elsif no_comment_zone? ast
          begin_pos = ast.location.expression.begin.begin_pos
          end_pos   = ast.location.expression.end.end_pos
          found_ranges << (begin_pos...end_pos)
        else
          ast.children.each { |child| ranges_of_atomic_expressions child, found_ranges }
        end
        found_ranges
      end

      def no_comment_zone?(ast)
        case ast.type
        when :dstr, :str, :xstr, :regexp
          true
        when :array
          the_begin = ast.location.begin
          the_begin && the_begin.source =~ /\A%/
        else
          false
        end
      end

      # copy/pasted from wrap_expressions
      def heredoc?(ast)
        # some strings are fucking weird.
        # e.g. the "1" in `%w[1]` returns nil for ast.location.begin
        # and `__FILE__` is a string whose location is a Parser::Source::Map instead of a Parser::Source::Map::Collection, so it has no #begin
        ast.kind_of?(Parser::AST::Node)           &&
          (ast.type == :dstr || ast.type == :str) &&
          (location  = ast.location)              &&
          (location.respond_to?(:begin))          &&
          (the_begin = location.begin)            &&
          (the_begin.source =~ /^\<\<-?/)
      end

      def remove_lines_after_data_segment
        data_segment_line, _ = line_nums_to_last_index_and_col.find do |line_number, (end_index, col)|
          if end_index == 7
            code.start_with? '__END__'
          elsif end_index < 7
            false
          else
            code[(end_index-8)...end_index] == "\n__END__"
          end
        end
        return unless data_segment_line
        max_line = line_nums_to_last_index_and_col.keys.max
        data_segment_line.upto(max_line) { |line_number| line_nums_to_last_index_and_col.delete line_number }
      end

      def add_comments_to(commentable_lines)
        commentable_lines.each do |line_number, (index_of_newline, col)|
          first_index  = last_index = index_of_newline
          first_index -= 1 while first_index > 0 && code[first_index-1] != "\n"
          comment_text = commenter.call code[first_index...last_index], line_number
          range        = Parser::Source::Range.new(buffer, first_index, last_index)
          rewriter.insert_after range, comment_text
        end
      end
    end
  end
end
