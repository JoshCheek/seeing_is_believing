require 'ripper'

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
      return beginning == ending if beginning.size == 1
      case beginning[-1]
      when '<' then '>' == ending
      when '(' then ')' == ending
      when '[' then ']' == ending
      when '{' then '}' == ending
      else
        beginning[-1] == ending
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
      parsed(code).valid_ruby?
    end

    def valid_ruby?
      !invalid_ruby?
    end

    def invalid_ruby?
      @has_error || unclosed_string? || unclosed_regexp?
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

    def self.ends_in_comment?(code)
      parsed(code.lines.to_a.last.to_s).has_comment?
    end

    def has_comment?
      @has_comment
    end

    def on_comment(*)
      @has_comment = true
      super
    end

    # RETURNS

    # this is conspicuosuly inferior, but I can't figure out how to actually parse it
    # see: http://www.ruby-forum.com/topic/4409633
    def self.will_return?(code)
      /(^|\s)return.*?\Z$/ =~ code
    end
  end
end
