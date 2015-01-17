require 'seeing_is_believing/wrap_expressions'
class SeeingIsBelieving
  module WrapExpressionsWithInspect
    def self.call(program)
      WrapExpressions.call program,
        before_each: -> line_number {
          "("
        },
        after_each:  -> line_number {
          ").tap { |v| $SiB.record_result(:inspect, #{line_number}, v) }"
        }
    end
  end
end
