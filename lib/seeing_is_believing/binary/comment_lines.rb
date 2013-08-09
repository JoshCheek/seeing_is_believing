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

      class CommentLines2
        def self.call(code, &commenter)
          buffer         = Parser::Source::Buffer.new "strip_comments"
          buffer.source  = code
          buffer         = buffer # oh ffs, fucking fix this
          parser         = Parser::CurrentRuby.new
          rewriter       = Parser::Source::Rewriter.new(buffer)
          root, comments = parser.parse_with_comments(buffer)
          lines_and_indexes = code.each_char
                                  .with_index
                                  .select { |char, index| char == "\n" }
                                  .each_with_object(Hash.new) { |(_, index), hash|
                                    line, col = buffer.decompose_position index
                                    hash[line] = index
                                  }

          if code[code.size-1] != "\n"
            line, col = buffer.decompose_position code.size
            lines_and_indexes[line] = code.size
          end

          # can't comment when there is already a comment
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

          # can't comment if the newline is escaped
          lines_and_indexes.select { |_, index_of_newline|
            # will this be a problem if there are empty lines at the top of the file?
            code[index_of_newline-1] == '\\'
          }.each { |line_number, _|
            lines_and_indexes.delete line_number
          }

          # can't add a comment if inside a string/regex/etc
          invalid_boundaries = ranges_of_atomic_expressions root, []
          invalid_boundaries.each do |invalid_boundary|
            lines_and_indexes.select { |_, index_of_newline|
              invalid_boundary.include? index_of_newline
            }.each { |line_number, _|
              lines_and_indexes.delete line_number
            }
          end


          # add the comments
          lines_and_indexes.each do |line_number, index_of_newline|
            first_index  = last_index = index_of_newline
            first_index -= 1 while first_index > 0 && code[first_index-1] != "\n"
            comment_text = commenter.call code[first_index...last_index], line_number
            range        = Parser::Source::Range.new(buffer, first_index, last_index)
            rewriter.insert_after range, comment_text
          end

          rewriter.process
        end

        def self.ranges_of_atomic_expressions(ast, found_ranges)
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
      end

      # keeping this just cuz I put a lot of work into it and might want to come back to it
      # but we're going to probably use the above approach instead
      def call
        return CommentLines2.call(code, &commenter)
        buffer                = Parser::Source::Buffer.new "strip_comments"
        buffer.source         = code
        self.buffer = buffer # oh ffs, fucking fix this
        parser                = Parser::CurrentRuby.new
        rewriter              = Parser::Source::Rewriter.new(buffer)
        root, comments        = parser.parse_with_comments(buffer)

        line_numbers_last_indexes(root).sort_by(&:first).each do |line_number, last_index|
          source = buffer.source
          first_index = last_index
          first_index -= 1 while first_index > 0 && source[first_index-1] != "\n"
          last_index  += 1 while source[last_index] !~ /[\n#\\]/ && last_index < source.size

          # make sure we found the end and not like a comment or whatever
          next unless source[last_index] == "\n" || source[last_index].nil?

          comment_text = commenter.call source[first_index...last_index], line_number
          range        = Parser::Source::Range.new(buffer, first_index, last_index)
          rewriter.insert_after range, comment_text
        end
        rewriter.process
      end

      private

      attr_accessor :code, :commenter, :buffer

      def line_numbers_last_indexes(ast, results={})
        return results unless ast.kind_of? ::AST::Node
        case ast.type
        when :args
          # no op

          # we actually could record the end of an args list
          #   but since it does not need to have parens we can't trust the location
          #   so for now, fuck it, we aren't using that feature anyway
        when :if
          record results, ast.location.expression
          # not all ifs have elses, some ifs return Map::Keyword, others Map::Condition
          record results, ast.location.else if ast.location.respond_to?(:else) && ast.location.else
          record_children results, ast.children
        when :kwbegin
          record results, ast.location.begin
          record results, ast.location.expression
          record_children results, ast.children
        when :resbody
          record results, ast.location.keyword
          record_children results, ast.children
        else
          record results, ast.location.expression
          record_children results, ast.children
        end
        results
      rescue
        require "pry"
        binding.pry
      end

      def record(results, range)
        # have to use decompose_expression because we want it based on the line of the last char, not the first char
        index = range.end_pos
        line_number, col = buffer.decompose_position range.end_pos
        prev_index = results[line_number]
        results[line_number] = (!prev_index || prev_index < index ? index : prev_index)
      end

      def record_children(results, children)
        children.each { |child| line_numbers_last_indexes child, results }
      end
    end
  end
end

