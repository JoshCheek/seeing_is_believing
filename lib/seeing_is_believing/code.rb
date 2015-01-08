require 'parser_helpers' # b/c they silence warnings when requiring parser

class SeeingIsBelieving
  class Code
    InlineComment = Struct.new :line_number,
                               :whitespace_col,
                               :whitespace,
                               :text_col,
                               :text,
                               :full_range,
                               :whitespace_range,
                               :comment_range

    # At prsent, it is expected that the syntax is validated before code arrives here
    # or that its validity doesn't matter (e.g. extracting comments)
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

      can_parse_invalid_code(@parser)

      @root, all_comments, tokens = parser.tokenize(@buffer)

      @inline_comments = all_comments.select(&:inline?).map { |c| wrap_comment c }
    end

    def can_parse_invalid_code(parser)
      # THIS IS SO WE CAN EXTRACT COMMENTS FROM INVALID FILES.

      # We do it by telling Parser's diagnostic to not blow up.
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/diagnostic/engine.rb

      # However, this probably implies SiB won't work on Rbx/JRuby
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/base.rb#L129-134

      # Ideally we could just do this
      #   parser.diagnostics.all_errors_are_fatal = false
      #   parser.diagnostics.ignore_warnings      = false

      # But, the parser will still blow up on "fatal" errors (e.g. unterminated string) So we need to actually change it.
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/diagnostic/engine.rb#L99

      # We could make a NullDiagnostics like this:
      #   class NullDiagnostics < Parser::Diagnostic::Engine
      #     def process(*)
      #       # no op
      #     end
      #   end

      # But we don't control initialization of the variable, and the value gets passed around, at least into the lexer.
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/base.rb#L139
      #   and since it's all private, it could change at any time (Parser is very state based),
      #   so I think it's just generally safer to mutate that one object, as we do now.
      diagnostics = parser.diagnostics
      def diagnostics.process(*)
        self
      end
    end

    def wrap_comment(comment)
      last_char  = comment.location.expression.begin_pos
      first_char = last_char
      first_char -= 1 while first_char > 0 && code[first_char-1] =~ /[ \t]/
      preceding_whitespace        = buffer.source[first_char...last_char]
      preceding_whitespace_range  = range_for first_char, last_char

      InlineComment.new comment.location.line,
                        preceding_whitespace_range.column,
                        preceding_whitespace,
                        comment.location.column,
                        comment.text,
                        range_for(first_char, comment.location.expression.end_pos),
                        preceding_whitespace_range,
                        comment.location.expression
    end
  end
end
