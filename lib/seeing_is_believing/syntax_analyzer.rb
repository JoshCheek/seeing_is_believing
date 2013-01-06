require 'ripper'

class SeeingIsBelieving
  class SyntaxAnalyzer < Ripper::SexpBuilder

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

    def self.parsed(code)
      instance = new code
      instance.parse
      instance
    end

    def self.valid_ruby?(code)
      parsed(code).valid_ruby?
    end

    def self.ends_in_comment?(code)
      parsed(code.lines.to_a.last.to_s).has_comment?
    end

    def self.unclosed_string?(code)
      parsed(code).unclosed_string?
    end

    def self.unclosed_regexp?(code)
      parsed(code).unclosed_regexp?
    end

    def valid_ruby?
      !invalid_ruby?
    end

    def invalid_ruby?
      @has_error || unclosed_string?
    end

    def has_comment?
      @has_comment
    end

    def on_comment(*)
      @has_comment = true
      super
    end

    # We have to do this b/c Ripper sometimes calls on_tstring_end even when the string doesn't get ended
    # e.g. SyntaxAnalyzer.new('"a').parse
    ENDINGS_BY_BEGINNINGS = Hash.new { |_, char| char }
    ENDINGS_BY_BEGINNINGS['<'] = '>'
    ENDINGS_BY_BEGINNINGS['('] = ')'
    ENDINGS_BY_BEGINNINGS['['] = ']'
    ENDINGS_BY_BEGINNINGS['{'] = '}'

    # STRINGS

    def string_opens
      @string_opens ||= []
    end

    def on_tstring_beg(beginning)
      string_opens.push beginning
      super
    end

    def on_tstring_end(ending)
      string_opens.pop if string_opens.any? && ENDINGS_BY_BEGINNINGS[string_opens.last[-1]] == ending
      super
    end

    def unclosed_string?
      string_opens.any?
    end

    # REGEXPS

    def regexp_opens
      @regexp_opens ||= []
    end

    def on_regexp_beg(beginning)
      regexp_opens.push beginning
      super
    end

    def on_regexp_end(ending)
      regexp_opens.pop if regexp_opens.any? && ENDINGS_BY_BEGINNINGS[regexp_opens.last[-1]] == ending
      super
    end

    def unclosed_regexp?
      regexp_opens.any?
    end
  end
end
