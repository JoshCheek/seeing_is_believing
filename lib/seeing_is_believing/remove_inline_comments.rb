require 'parser/current'

class SeeingIsBelieving
  module RemoveInlineComments
    module NonLeading
      def self.call(code)
        ranges = []

        nonleading_comments = lambda do |buffer, rewriter|
          ranges.sort_by(&:begin_pos)
                .drop_while.with_index(1) { |range, index|
                  line, col = buffer.decompose_position range.begin_pos
                  index == line && col.zero?
                }
                .each { |range| rewriter.remove range }
        end

        RemoveInlineComments.call code, additional_rewrites: nonleading_comments do |comment|
          ranges << comment.location
          false
        end
      end
    end

    extend self

    # selector is a block that will receive the comment object
    # if it returns true, the comment will be removed
    def self.call(code, options={}, &selector)
      selector            ||= Proc.new { true }
      additional_rewrites   = options.fetch :additional_rewrites, Proc.new {}
      buffer                = Parser::Source::Buffer.new "strip_comments"
      buffer.source         = code
      parser                = Parser::CurrentRuby.new
      rewriter              = Parser::Source::Rewriter.new(buffer)
      ast, comments         = parser.parse_with_comments(buffer)
      comments.select { |comment| comment.type == :inline }
              .select { |comment| selector.call comment }
              .each   { |comment| rewriter.remove comment.location.expression }
      additional_rewrites.call buffer, rewriter
      rewriter.process
    rescue Parser::SyntaxError => e
      raise SyntaxError, e.message
    end
  end
end
