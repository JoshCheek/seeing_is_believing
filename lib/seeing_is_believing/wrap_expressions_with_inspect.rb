require 'seeing_is_believing/wrap_expressions'
class SeeingIsBelieving
  module WrapExpressionsWithInspect
    def self.call(program)
      # NOTE: if it received the AST, it could figure out if it needs
      # to always wrap the expression in parentheses
      WrapExpressions.call program,
        before_each: -> line_number {
          "$SiB.record_result(:inspect, #{line_number}, ("
        },
        after_each:  -> line_number {
          "))"
        }
    end
  end
end
