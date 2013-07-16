require 'parser/current'

class SeeingIsBelieving
  module RemoveInlineComments
    extend self

    # selector is a block that will receive the comment object
    # if it returns true, the comment will be removed
    def self.call(code, &selector)
      remove_inline_comments code, &selector
    end

    def remove_inline_comments(code, &selector)
      selector    ||= Proc.new { true }
      buffer        = Parser::Source::Buffer.new "strip_comments"
      buffer.source = code
      parser        = Parser::CurrentRuby.new
      rewriter      = Parser::Source::Rewriter.new(buffer)
      ast, comments = parser.parse_with_comments(buffer)
      comments.select { |comment| comment.type == :inline }
              .select { |comment| selector.call comment }
              .each   { |comment| rewriter.remove comment.location }
      rewriter.process
    rescue Parser::SyntaxError => e
      raise SyntaxError, e.message
    end
  end
end
