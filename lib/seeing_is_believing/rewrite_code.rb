require 'seeing_is_believing/wrap_expressions'
class SeeingIsBelieving
  module RewriteCode
    def self.call(program, options={})
      wrap_expressions_callbacks = {}
      wrap_expressions_callbacks[:before_all]  = options.fetch :before_all,  -> { "" }
      wrap_expressions_callbacks[:after_all]   = options.fetch :after_all,   -> { "" }
      wrap_expressions_callbacks[:before_each] = options.fetch :before_each, -> line_number { "(" }
      wrap_expressions_callbacks[:after_each]  = options.fetch :after_each,  -> line_number { ").tap { |v| $SiB.record_result(:inspect, #{line_number}, v) }" }
      WrapExpressions.call program, wrap_expressions_callbacks
    end
  end
end
