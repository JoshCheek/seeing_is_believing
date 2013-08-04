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

        ln2nac.each do |line_num, (node, last_col)|
          rewriter.send :insert_before, node.location.expression, before_each.call(line_num)
          rewriter.send :insert_after,  node.location.expression, after_each.call(line_num)
        end

        rewriter.send :insert_after,  root.location.expression, after_all

        rewriter.process
      end
    end

    def add_to_result(ast, buffer, result)
      line, col = buffer.decompose_position ast.location.expression.end_pos
      result[line] = if result[line]
                       _, prev_col = result[line]
                       if prev_col < col
                         [ast, col]
                       else
                         result[line]
                       end
                     else
                       [ast, col]
                     end
    end

    def line_nums_to_node_and_col(ast, buffer, result={})
      return result unless ast.kind_of? Parser::AST::Node
      # const?
      case ast.type
      when :args
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
      else
        # if ast.type == :str
        #   ast.type                                           # => :str
        #   ast.location.begin.source.match(/^\<\<-?/)         # => #<MatchData "<<-">
        # end                                                  # => nil, #<MatchData "<<-">

        add_to_result ast, buffer, result
        ast.children.each do |child|
          line_nums_to_node_and_col child, buffer, result                              # => {3=>(send nil :meth\n  (str "abc\n"))}, {3=>(send nil :meth\n  (str "abc\n"))}, {3=>(str "abc\n")}, {3=>(str "abc\n")}
        end                                                                    # => ["abc\n"], [nil, :meth, (str "abc\n")]
      end
      result
    rescue
      puts ast.type
      require "pry"
      binding.pry
    end                                                                      # => nil
  end
end
