module Parser
  class << self
    # With new versioning, there's lots of small versions
    # we don't need it to complain that we're on 2.1.1 and its parsing 2.1.5
    # https://github.com/whitequark/parser/blob/e2249d7051b1adb6979139928e14a81bc62f566e/lib/parser/current.rb#L3
    def warn(*) end
    require 'parser/current'
    remove_method :warn
  end
end

class SeeingIsBelieving
  module ParserHelpers

    # override #process so it does not raise an error on
    # fatal parsings (we want to keep going if possible,
    # this allows us to find comments in syntactically invalid files)
    class NullDiagnostics < Parser::Diagnostic::Engine
      def process(*)
        # no op
      end
    end

    extend self

    def initialize_parser(code, name)
      buffer                             = Parser::Source::Buffer.new(name)
      buffer.source                      = code

      builder                            = Parser::Builders::Default.new
      builder.emit_file_line_as_literals = false

      parser                             = Parser::CurrentRuby.new builder
      rewriter                           = Parser::Source::Rewriter.new buffer

      [buffer, parser, rewriter]
    end

    # useful b/c it can find comments even in syntactically invalid code
    def comments_from(parser, buffer)
      parser.instance_variable_set(:@diagnostics, NullDiagnostics.new) # seems really fucking risky
      success, comments, tokens, * = parser.tokenize buffer            # experimentally, seems to be what these things return
      comments
    end

    # this is the scardest fucking method I think I've ever written.
    # *anything* can go wrong!
    def heredoc?(ast)
      # some strings are fucking weird.
      # e.g. the "1" in `%w[1]` returns nil for ast.location.begin
      # and `__FILE__` is a string whose location is a Parser::Source::Map instead of a Parser::Source::Map::Collection,
      # so it has no #begin
      ast.kind_of?(Parser::AST::Node)           &&
        (ast.type == :dstr || ast.type == :str) &&
        (location  = ast.location)              &&
        (ast.location.kind_of? Parser::Source::Map::Heredoc)
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
      return ast
      return ast unless heredoc? ast
      Parser::AST::Node.new :str,
                            [],
                            location: Parser::Source::Map.new(ast.location.begin)
    end
  end
end
