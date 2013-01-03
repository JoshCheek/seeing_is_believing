require 'ripper'

class SyntaxAnalyzer < Ripper::SexpBuilder

  # I don't actually know if all of the error methods should invoke has_error!
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
        @has_error = true
        super
      end
    "
  end

  def on_comment(*)
    @has_comment = true
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
    parsed(code.lines.to_a.last).has_comment?
  end

  def has_error?
    @has_error
  end

  def has_comment?
    @has_comment
  end
end
