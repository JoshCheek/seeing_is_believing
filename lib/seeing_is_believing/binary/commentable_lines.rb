require 'seeing_is_believing/code'

class SeeingIsBelieving
  module Binary

    class CommentableLines
      def self.call(code)
        new(code).call
      end

      def initialize(code)
        self.code = code
        self.code_obj = Code.new(code, 'finding_commentable_lines')
      end

      def call
        @call ||= begin
          line_num_to_location = line_nums_to_last_index_and_col(buffer)
          remove_lines_after_data_segment           line_num_to_location
          remove_lines_whose_newline_is_escaped     line_num_to_location
          remove_lines_ending_in_comments           line_num_to_location, code_obj.raw_comments
          remove_lines_inside_of_strings_and_things line_num_to_location, root
          line_num_to_location
        end
      end

      def buffer
        code_obj.buffer
      end

      def rewriter
        code_obj.rewriter
      end

      private

      attr_writer :buffer, :rewriter
      attr_accessor :code, :code_obj

      def root
        code_obj.root
      end

      def line_nums_to_last_index_and_col(buffer)
        code.each_char
            .with_index
            .select { |char, index| char == "\n" }
            .each_with_object(Hash.new) do |(_, index), hash|
              line, col = buffer.decompose_position index
              hash[line] = [index, col]
            end
      end

      def remove_lines_whose_newline_is_escaped(line_num_to_location)
        line_num_to_location.select { |line_number, (index_of_newline, col)| code[index_of_newline-1] == '\\' }
                            .each   { |line_number, (index_of_newline, col)| line_num_to_location.delete line_number }
      end

      def remove_lines_ending_in_comments(line_num_to_location, comments)
        comments.each do |comment|
          if comment.type == :inline
            line_num_to_location.delete comment.location.line
          else
            begin_pos = comment.location.expression.begin_pos
            end_pos   = comment.location.expression.end_pos
            range     = begin_pos...end_pos
            line_num_to_location.select { |line_number, (index_of_newline, col)| range.include? index_of_newline }
                                .each   { |line_number, (index_of_newline, col)| line_num_to_location.delete line_number }
          end
        end
      end

      def remove_lines_inside_of_strings_and_things(line_num_to_location, ast)
        invalid_boundaries = ranges_of_atomic_expressions ast, []
        invalid_boundaries.each do |invalid_boundary|
          line_num_to_location.select { |line_number, (index_of_newline, col)| invalid_boundary.include? index_of_newline }
                              .each   { |line_number, (index_of_newline, col)| line_num_to_location.delete line_number }
        end
      end

      def ranges_of_atomic_expressions(ast, found_ranges)
        return found_ranges unless ast.kind_of? ::AST::Node
        if no_comment_zone?(ast) && code_obj.heredoc?(ast)
          begin_pos = ast.location.heredoc_body.begin_pos
          end_pos   = ast.location.heredoc_end.end_pos.next
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

      def remove_lines_after_data_segment(line_num_to_location)
        end_index = code_obj.body_range.end_pos
        body_end  = code_obj.index_to_linenum end_index
        file_end  = line_num_to_location.keys.max
        body_end.upto(file_end) { |line_number| line_num_to_location.delete line_number }
      end
    end
  end
end
