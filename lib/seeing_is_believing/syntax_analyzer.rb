require 'ripper'
require 'parser/current'

class SeeingIsBelieving
  class SyntaxAnalyzer < Ripper::SexpBuilder

    # HELPERS

    def self.parsed(code)
      instance = new code
      instance.parse
      instance
    end

    # SYNTACTIC VALIDITY

    def self.begins_multiline_comment?(line)
      line == '=begin'
    end

    def self.ends_multiline_comment?(line)
      line == '=end'
    end

    def self.begin_and_end_comments_are_complete?(code)
      code.scan(/^=(?:begin|end)$/)
          .each_slice(2)
          .all? { |b, e| b == '=begin' && e == '=end' }
    end

    # MISC

    def self.begins_data_segment?(line)
      line == '__END__'
    end

    # COMMENTS

    def self.line_is_comment?(line)
      line =~ /^\s*#/
    end

    def self.ends_in_comment?(code)
      # must do the newline hack or it totally fucks up on comments like "# Transfer-Encoding: chunked"
      code =~ /^=end\Z/ || parsed("\n#{code.lines.to_a.last.to_s}").has_comment?
    end

    def self.unclosed_comment?(code)
      !begin_and_end_comments_are_complete?(code)
    end

    def has_comment?
      @has_comment
    end

    def on_comment(*)
      @has_comment = true
      super
    end
  end
end
