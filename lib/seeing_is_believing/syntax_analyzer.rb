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

    # We have to do this b/c Ripper sometimes calls on_tstring_end even when the string doesn't get ended
    # e.g. SyntaxAnalyzer.new('"a').parse
    def ends_match?(beginning, ending)
      return false unless beginning && ending
      return beginning == ending if beginning.size == 1 && ending.size == 1
      case beginning[-1]
      when '<' then '>' == ending
      when '(' then ')' == ending
      when '[' then ']' == ending
      when '{' then '}' == ending
      when '/' then ending =~ /\A\// # example: /a/x
      else
        # example: %Q.a. %_a_ %r|a| ...
        beginning.start_with?('%') && beginning.end_with?(ending)
      end
    end

    # SYNTACTIC VALIDITY

    # I don't actually know if all of the error methods should set @has_error
    # or just parse errors. I don't actually know how to produce the other errors O.o
    #
    # Here is what it is defining as of ruby-1.9.3-p125:
    #   on_alias_error
    #   on_assign_error
    #   on_class_name_error
    #   on_param_error
    #   on_parse_error
    instance_methods.grep(/error/i).each do |error_meth|
      super_meth = instance_method error_meth
      define_method error_meth do |*args, &block|
        @has_error = true
        super_meth.bind(self).call(*args, &block)
      end
    end

    def self.valid_ruby?(code)
      parsed(code).valid_ruby? && begin_and_end_comments_are_complete?(code)
    end

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

    def valid_ruby?
      !invalid_ruby?
    end

    def invalid_ruby?
      @has_error || unclosed_string? || unclosed_regexp?
    end

    # MISC

    def self.begins_data_segment?(line)
      line == '__END__'
    end

    def self.next_line_modifies_current?(line)
      line =~ /^\s*\./
    end

    # STRINGS

    def self.unclosed_string?(code)
      parsed(code).unclosed_string?
    end

    def string_opens
      @string_opens ||= []
    end

    def on_tstring_beg(beginning)
      string_opens.push beginning
      super
    end

    def on_tstring_end(ending)
      string_opens.pop if ends_match? string_opens.last, ending
      super
    end

    def unclosed_string?
      string_opens.any?
    end

    # REGEXPS

    def self.unclosed_regexp?(code)
      parsed(code).unclosed_regexp?
    end

    def regexp_opens
      @regexp_opens ||= []
    end

    def on_regexp_beg(beginning)
      regexp_opens.push beginning
      super
    end

    def on_regexp_end(ending)
      regexp_opens.pop if ends_match? regexp_opens.last, ending
      super
    end

    def unclosed_regexp?
      regexp_opens.any?
    end

    # COMMENTS

    def self.line_is_comment?(line)
      line =~ /^\s*#/
    end

    def self.ends_in_comment?(code)
      code =~ /^=end\Z/ || parsed(code.lines.to_a.last.to_s).has_comment?
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

    # RETURNS

    def self.void_value_expression?(code_or_ast)
      ast = code_or_ast
      ast = Parser::CurrentRuby.parse(code_or_ast) if code_or_ast.kind_of? String

      case ast && ast.type
      when :begin, :kwbegin, :resbody # begin and kwbegin should be the same thing, but it changed in parser 1.4.1 to 2.0.0, so just adding them both for safety
        void_value_expression?(ast.children[-1])
      when :rescue, :ensure
        ast.children.any? { |child| void_value_expression? child }
      when :if
        void_value_expression?(ast.children[1]) || void_value_expression?(ast.children[2])
      when :return, :next, :redo, :retry, :break
        true
      else
        false
      end
    end

    # HERE DOCS

    def self.here_doc?(code)
      instance = parsed code
      instance.has_heredoc? && code.scan("\n").size.next <= instance.here_doc_last_line_number
    end

    def heredocs
      @heredocs ||= []
    end

    def on_heredoc_beg(beginning)
      heredocs << [beginning]
      super
    end

    def on_heredoc_end(ending)
      result      = super
      line_number = result.last.first
      doc = heredocs.find { |(beginning)| beginning.include? ending.strip }
      doc << ending << line_number
      result
    end

    def has_heredoc?
      heredocs.any?
    end

    def here_doc_last_line_number
      heredocs.last.last
    end
  end
end
