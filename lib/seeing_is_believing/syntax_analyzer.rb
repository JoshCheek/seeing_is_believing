require 'ripper'

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
    class_eval "
      def #{error_meth}(*)
        # puts 'ERROR: #{error_meth}'
        @has_error = true
        super
      end
    "
  end

  def initialize(*)
    @string_opens = []
    super
  end

  def self.parsed(code)
    instance = new code
    instance.parse
    instance
  end

  def self.valid_ruby?(code)
    !parsed(code).has_error?
  end

  def self.ends_in_comment?(code)
    parsed(code.lines.to_a.last.to_s).has_comment?
  end

  def self.unclosed_string?(code)
    parsed(code).unclosed_string?
  end

  def has_error?
    @has_error
  end

  def has_comment?
    @has_comment
  end

  def on_comment(*)
    @has_comment = true
    super
  end

  STRING_MAP = Hash.new { |_, char| char }
  STRING_MAP['<'] = '>'
  STRING_MAP['('] = ')'
  STRING_MAP['['] = ']'
  STRING_MAP['{'] = '}'

  def on_tstring_beg(opener)
    @string_opens << opener
    super
  end

  def on_tstring_end(ending)
    if @string_opens.any? && STRING_MAP[@string_opens.last.chars.to_a.last] == ending
      @string_opens.pop
    end
    super
  end

  def unclosed_string?
    @string_opens.any?
  end
end
