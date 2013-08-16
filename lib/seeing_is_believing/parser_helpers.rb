require 'parser/current'
class SeeingIsBelieving
  module ParserHelpers
    extend self

    def initialize_parser(code, name)
      buffer                             = Parser::Source::Buffer.new(name)
      buffer.source                      = code
      builder                            = Parser::Builders::Default.new
      builder.emit_file_line_as_literals = false
      parser                             = Parser::CurrentRuby.new builder
      root, comments                     = parser.parse_with_comments buffer
      rewriter                           = Parser::Source::Rewriter.new buffer
      [buffer, parser, rewriter, root, comments]
    end

    # this is the scardest fucking method I think I've ever written.
    # *anything* can go wrong!
    def heredoc?(ast)
      # some strings are fucking weird.
      # e.g. the "1" in `%w[1]` returns nil for ast.location.begin
      # and `__FILE__` is a string whose location is a Parser::Source::Map instead of a Parser::Source::Map::Collection, so it has no #begin
      ast.kind_of?(Parser::AST::Node)           &&
        (ast.type == :dstr || ast.type == :str) &&
        (location  = ast.location)              &&
        (the_begin = location.begin)            &&
        (the_begin.source =~ /^\<\<-?/)
    end

    def void_value?(ast)
      case ast && ast.type
      when :begin, :kwbegin, :resbody
        void_value?(ast.children[-1])
      when :rescue, :ensure
        ast.children.any? { |child| void_value? child }
      when :if
        void_value?(ast.children[1]) || void_value?(ast.children[2])
      when :return, :next, :redo, :retry, :break
        true
      else
        false
      end
    end

    def heredoc_hack(ast)
      return ast unless heredoc? ast
      Parser::AST::Node.new :str,
                            [],
                            location: Parser::Source::Map.new(ast.location.begin)
    end
  end
end
