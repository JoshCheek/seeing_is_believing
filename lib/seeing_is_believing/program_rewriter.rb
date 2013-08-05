require 'parser/current'

class SeeingIsBelieving
  class ProgramReWriter
    def self.call(program, wrappings)
      new(program, wrappings).call
    end

    attr_accessor :program, :before_all, :after_all, :before_each, :after_each, :buffer, :root, :rewriter

    def initialize(program, wrappings)
      self.program     = program
      self.before_all  = wrappings.fetch :before_all,  ''.freeze
      self.after_all   = wrappings.fetch :after_all,   ''.freeze
      self.before_each = wrappings.fetch :before_each, -> * { '' }
      self.after_each  = wrappings.fetch :after_each,  -> * { '' }
      self.buffer      = Parser::Source::Buffer.new('program-without-annotations')
      buffer.source    = program
      self.root        = Parser::CurrentRuby.new.parse buffer
      self.rewriter    = Parser::Source::Rewriter.new buffer
    end

    def call
      @result ||= begin
        ln2nac = line_nums_to_node_and_col root, buffer
        # p ln2nac

        rewriter.send :insert_before, root.location.expression, before_all

        ln2nac.each do |line_num, (range, last_col)|
          rewriter.send :insert_before, range, before_each.call(line_num)
          rewriter.send :insert_after,  range, after_each.call(line_num)
        end

        rewriter.send :insert_after,  root.location.expression, after_all

        rewriter.process
      end
    end

    def add_to_result(range_or_ast, buffer, result)
      range = range_or_ast
      range = range_or_ast.location.expression if range.kind_of? ::AST::Node
      line, col = buffer.decompose_position range.end_pos
      result[line] = if result[line]
                       _, prev_col = result[line]
                       if prev_col < col
                         [range, col]
                       else
                         result[line]
                       end
                     else
                       [range, col]
                     end
    end

    def line_nums_to_node_and_col(ast, buffer, result={})
      return result unless ast.kind_of? ::AST::Node

      case ast.type
      when :args
      when :rescue, :ensure
        ast.children.each { |child| line_nums_to_node_and_col child, buffer, result }
      when :if
        keyword = ast.location.keyword.source
        if keyword == 'if' || keyword == 'unless'
          add_to_result ast, buffer, result
        end
        ast.children.each { |child| line_nums_to_node_and_col child, buffer, result }
      when :when
        line_nums_to_node_and_col ast.children.last, buffer, result
      when :resbody
        exception_type, variable_name, body = ast.children
        line_nums_to_node_and_col body, buffer, result
      when :class, :module
        add_to_result ast, buffer, result
        ast.children.drop(1).each do |child|
          line_nums_to_node_and_col child, buffer, result
        end
      when :block
        add_to_result ast, buffer, result
        ast.children.drop(1).each do |child|
          line_nums_to_node_and_col child, buffer, result
        end
      when :masgn
        # we must look at RHS because [1,<<A] and 1,<<A are both allowed
        #
        # in the first case, we must take the end_pos of the array, or we'll insert the after_each in the wrong location
        #
        # in the second, there is an implicit Array wrapped around it, with the wrong end_pos,
        # so we must take the end_pos of the last arg
        array = ast.children.last
        if array.location.expression.source.start_with? '['
          add_to_result ast, buffer, result
          line_nums_to_node_and_col array, buffer, result
        else
          begin_pos = ast.location.expression.begin_pos
          end_pos   = heredoc_hack(ast.children.last.children.last).location.expression.end_pos
          range     = Parser::Source::Range.new buffer, begin_pos, end_pos
          add_to_result range, buffer, result
          ast.children.last.children.each { |child| line_nums_to_node_and_col child, buffer, result }
        end
      when :lvasgn
        # because the RHS can be a heredoc, and parser currently handles heredocs locations incorrectly
        # we must hack around this

        # can have one or two children:
        #   in a=1 (has children :a, and 1)
        #   in a,b=1,2 it comes out like:
        #     (masgn
        #       (mlhs
        #         (lvasgn :a) <-- one child
        #
        #         (lvasgn :b))
        #       (array
        #         (int 1)
        #         (int 2)))
        if ast.children.size == 2
          begin_pos = ast.location.expression.begin_pos
          end_pos   = heredoc_hack(ast.children.last).location.expression.end_pos
          range     = Parser::Source::Range.new buffer, begin_pos, end_pos
          add_to_result range, buffer, result

          ast.children.each { |child| line_nums_to_node_and_col child, buffer, result }
        end
      when :send
        # because the target and the last child can be heredocs
        # and the method may or may not have parens,
        # it can inadvertently inherit the incorrect location of the heredocs
        # so we check for this case, that way we can construct the correct range instead
        range = ast.location.expression

        # first two children: target, message, so we want the last child only if it is an argument
        target, message, *, last_arg = ast.children

        # last arg is a heredoc, use the closing paren, or the end of the first line of the heredoc
        if heredoc? last_arg
          end_pos = heredoc_hack(last_arg).location.expression.end_pos
          if buffer.source[ast.location.selector.end_pos] == '('
            end_pos += 1 until buffer.source[end_pos] == ')'
            end_pos += 1
          end

        # the last arg is not a heredoc, the range of the expression can be trusted
        elsif last_arg
          end_pos = ast.location.expression.end_pos

        # there is no last arg, but there are parens, find the closing paren
        # we can't trust the expression range because the target could be a heredoc
        elsif buffer.source[ast.location.selector.end_pos] == '('
          closing_paren_index = ast.location.selector.end_pos + 1
          closing_paren_index += 1 until buffer.source[closing_paren_index] == ')'
          end_pos = closing_paren_index + 1

        # use the selector because we can't trust expression since target can be a heredoc
        elsif heredoc? target
          end_pos = ast.location.selector.end_pos

        # use the expression because it could be something like !1, in which case the selector would return the rhs of the !
        else
          end_pos = ast.location.expression.end_pos
        end

        begin_pos = ast.location.expression.begin_pos
        range = Parser::Source::Range.new buffer, begin_pos, end_pos
        add_to_result range, buffer, result

        ast.children.each { |child| line_nums_to_node_and_col child, buffer, result }
      when :dstr
        ast = heredoc_hack ast
        add_to_result ast, buffer, result
      when :str
        add_to_result ast, buffer, result
      else
        add_to_result ast, buffer, result
        ast.children.each do |child|
          line_nums_to_node_and_col child, buffer, result
        end
      end
      result
    rescue
      puts ast.type
      puts $!
      require "pry"
      binding.pry
    end

    def heredoc_hack(ast)
      return ast unless heredoc? ast
      Parser::AST::Node.new :str,
                            [],
                            location: Parser::Source::Map.new(ast.location.begin)
    end

    def heredoc?(ast)
      return false unless ast.kind_of?(Parser::AST::Node) && ast.type == :dstr
      ast.location.begin.source =~ /^\<\<-?/
    end
  end
end
