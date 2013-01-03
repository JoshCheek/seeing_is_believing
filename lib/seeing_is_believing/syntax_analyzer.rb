require 'ripper'

class SyntaxRecorder < Ripper::SexpBuilder

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
        has_error!
        super
      end
    "
  end

  def self.valid_ruby?(code)
    instance = new code
    instance.parse
    !instance.has_error?
  end

  def has_error?
    @error
  end

  def has_error!
    @error = true
  end
end
