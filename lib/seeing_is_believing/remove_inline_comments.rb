require 'parser/current'

class SeeingIsBelieving
  module RemoveInlineComments
    extend self

    def self.call(code)
      remove_inline_comments code
    end

    def remove_inline_comments(code)
      buffer        = Parser::Source::Buffer.new "strip_comments"
      buffer.source = code
      parser        = Parser::CurrentRuby.new
      rewriter      = Parser::Source::Rewriter.new(buffer)
      ast, comments = parser.parse_with_comments(buffer)
      comments.select { |comment| comment.type == :inline }
              .each   { |comment| rewriter.remove comment.location }
      rewriter.process
    end
  end
end
