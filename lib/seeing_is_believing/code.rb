# With new versioning, there's lots of small versions
# we don't need Parser to complain that we're on 2.1.1 and its parsing 2.1.5
# https://github.com/whitequark/parser/blob/e2249d7051b1adb6979139928e14a81bc62f566e/lib/parser/current.rb#L3
class << (Parser ||= Module.new)
  def warn(*) end
  require 'parser/current'
  remove_method :warn
end

require 'seeing_is_believing/hash_struct'

class SeeingIsBelieving
  class Code
    InlineComment = HashStruct.for :line_number, :whitespace_col, :whitespace, :text_col, :text, :full_range, :whitespace_range, :comment_range
    Syntax = HashStruct.for error_message: nil, line_number: nil do
      def valid?()   !error_message end
      def invalid?() !valid?        end
    end

    attr_reader :raw, :buffer, :parser, :rewriter, :inline_comments, :root, :raw_comments, :syntax, :body_range

    def initialize(raw_code, name=nil)
      raw_code[-1] == "\n" || raise(SyntaxError, "Code must end in a newline for the sake of consistency (sanity)")
      @raw             = raw_code
      @buffer          = Parser::Source::Buffer.new(name||"SeeingIsBelieving")
      @buffer.source   = raw
      @rewriter        = Parser::Source::Rewriter.new buffer
      builder          = Parser::Builders::Default.new.tap { |b| b.emit_file_line_as_literals = false }
      @parser          = Parser::CurrentRuby.new builder
      @syntax          = Syntax.new
      parser.diagnostics.consumer = lambda do |diagnostic|
        if :fatal == diagnostic.level || :error == diagnostic.level
          @syntax = Syntax.new error_message: diagnostic.message, line_number: index_to_linenum(diagnostic.location.begin_pos)
        end
      end
      @root, @raw_comments, @tokens = parser.tokenize(@buffer, true)
      @body_range                   = body_range_from_tokens(@tokens)
      @inline_comments              = raw_comments.select(&:inline?).map { |c| wrap_comment c }
      @root                       ||= null_node
    end

    def range_for(start_index, end_index)
      Parser::Source::Range.new buffer, start_index, end_index
    end

    def index_to_linenum(char_index)
      line_indexes.index { |line_index| char_index < line_index } || line_indexes.size
    end

    def linenum_to_index(line_num)
      return raw.size if line_indexes.size < line_num
      line_indexes[line_num - 1]
    end

    def heredoc?(ast)
      # some strings are fucking weird.
      # e.g. the "1" in `%w[1]` returns nil for ast.location.begin
      # and `__FILE__` is a string whose location is a Parser::Source::Map instead of a Parser::Source::Map::Collection,
      # so it has no #begin
      ast.kind_of?(Parser::AST::Node)           &&
        (ast.type == :dstr || ast.type == :str) &&
        (location = ast.location)               &&
        (location.kind_of? Parser::Source::Map::Heredoc)
    end

    def void_value?(ast)
      case ast && ast.type
      when :begin, :kwbegin, :resbody
        void_value?(ast.children.last)
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

    def line_indexes
      @line_indexes ||= [ 0,
                          *raw.each_char
                              .with_index(1)
                              .select { |char, index| char == "\n" }
                              .map    { |char, index| index },
                        ].freeze
    end

    private

    def comments_and_tokens(builder, buffer)
      parser = Parser::CurrentRuby.new builder
      _, all_comments, tokens = parser.tokenize(@buffer, true)
      [all_comments, tokens]
    end

    def body_range_from_tokens(tokens)
      return range_for(0, 0) if raw.start_with? "__END__\n"
      (name, (_, range)) = tokens.max_by { |name, (data, range)| range.end_pos } ||
                            [nil, [nil, range_for(0, 1)]]
      end_pos = range.end_pos
      end_pos += 1 if name == :tCOMMENT || name == :tSTRING_END #
      range_for 0, end_pos
    end

    def wrap_comment(comment)
      last_char  = comment.location.expression.begin_pos
      first_char = last_char
      first_char -= 1 while first_char > 0 && raw[first_char-1] =~ /[ \t]/
      preceding_whitespace        = buffer.source[first_char...last_char]
      preceding_whitespace_range  = range_for first_char, last_char

      InlineComment.new line_number:      comment.location.line,
                        whitespace_col:   preceding_whitespace_range.column,
                        whitespace:       preceding_whitespace,
                        text_col:         comment.location.column,
                        text:             comment.text,
                        full_range:       range_for(first_char, comment.location.expression.end_pos),
                        whitespace_range: preceding_whitespace_range,
                        comment_range:    comment.location.expression
    end

    def null_node
      location = Parser::Source::Map::Collection.new nil, nil, range_for(0, 0)
      Parser::AST::Node.new :null_node, [], location: location
    end

  end
end
