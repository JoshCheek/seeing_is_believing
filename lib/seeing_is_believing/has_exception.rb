class SeeingIsBelieving
  module HasException
    attr_accessor :exception
    alias has_exception? exception

    # NOTE:
    #   zomg, so YAML doesn't serialize an exception's backtrace
    #   and Marshal gets all horked on windows (something like Marshal data too short)
    #   so I'm going back to YAML, but independently storing the backtrace
    #   It will need to get manually set back onto the exception
    #
    #   However, there is no Exception#backtrace=, so I have to redefine the method
    #   which sucks b/c of cache busting and so forth
    #   but that probably doesn't actually matter for any real-world use case of SeeingIsBelieving

    def exception=(exception)
      @exception = exception
      @exception_backtrace = exception.backtrace
    end

    def fix_exception_backtraces_after_yaml_serialization
      return unless exception
      exception_backtrace = @exception_backtrace
      exception.define_singleton_method(:backtrace) { exception_backtrace }
      self
    end
  end
end
