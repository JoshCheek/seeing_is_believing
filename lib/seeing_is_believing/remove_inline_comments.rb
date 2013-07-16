require 'parser/current'

class SeeingIsBelieving
  module RemoveInlineComments
    extend self

    # selector is a block that will receive the comment object
    # if it returns true, the comment will be removed
    def self.call(code, options={}, &selector)
      remove_inline_comments code, options, &selector
    end

    # uhm, can we clean this up a bit?
    def remove_inline_comments(code, options={}, &selector)
      selector    ||= Proc.new { true }
      additional_rewrites = options.fetch :additional_rewrites, Proc.new {}
      buffer        = Parser::Source::Buffer.new "strip_comments"
      buffer.source = code
      parser        = Parser::CurrentRuby.new
      rewriter      = Parser::Source::Rewriter.new(buffer)
      ast, comments = parser.parse_with_comments(buffer)
      comments.select { |comment| comment.type == :inline }
              .select { |comment| selector.call comment }
              .each   { |comment| rewriter.remove comment.location }
      additional_rewrites.call buffer, rewriter
      rewriter.process
    rescue Parser::SyntaxError => e
      raise SyntaxError, e.message
    end
  end
end
