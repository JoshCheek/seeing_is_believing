require 'parser/current'
class SeeingIsBelieving
  class Code
    InlineComment = Struct.new :line_number,
                               :column_number,
                               :whitespace,
                               :text,
                               :whitespace_range,
                               :comment_range

    class NullDiagnostics < Parser::Diagnostic::Engine
      def process(*)
        # no op
      end
    end

    def initialize(raw_ruby_code, name="SeeingIsBelieving")
      self.code = raw_ruby_code
      self.name = name
    end

    def buffer()          @buffer   ||= (parse && @buffer         ) end
    def parser()          @parser   ||= (parse && @parser         ) end
    def rewriter()        @rewriter ||= (parse && @rewriter       ) end
    def inline_comments() @comments ||= (parse && @inline_comments) end
    def root()            @root     ||= (parse && @root           ) end

    def range_for(start_index, end_index)
      Parser::Source::Range.new buffer, start_index, end_index
    end

    private

    attr_accessor :code, :name

    def parse
      @buffer                             = Parser::Source::Buffer.new(name)
      @buffer.source                      = code
      builder                             = Parser::Builders::Default.new
      builder.emit_file_line_as_literals  = false # should be injectible?
      @parser                             = Parser::CurrentRuby.new builder
      @rewriter                           = Parser::Source::Rewriter.new @buffer

      # Should be valid if it got this far and its going to be used
      # So NullDiagnostics doesn't matter (but we still want to be able to extract comments from syntactially invalid files)
      # Setting the ivar seems risky, though
      parser.instance_variable_set(:@diagnostics, NullDiagnostics.new)
      @root, all_comments, tokens = parser.tokenize(@buffer)

      @inline_comments = all_comments.select(&:inline?).map { |c| wrap_comment c }
    end

    def wrap_comment(comment)
      last_char  = comment.location.expression.begin_pos
      first_char = last_char
      first_char -= 1 while first_char > 0 && code[first_char-1] =~ /[ \t]/
      preceding_whitespace        = buffer.source[first_char...last_char]
      preceding_whitespace_range  = range_for first_char, last_char

      InlineComment.new comment.location.line,
                        comment.location.column,
                        preceding_whitespace,
                        comment.text,
                        preceding_whitespace_range,
                        comment.location.expression
    end
  end
end
