require 'seeing_is_believing/wrap_expressions'
class SeeingIsBelieving
  module InspectExpressions
    def self.call(program, filename, number_of_captures, options={})
      # TODO: much of this is duplicated in annotate_xmpfilter_stle
      number_of_captures_as_str = number_of_captures.inspect
      number_of_captures_as_str = 'Float::INFINITY' if number_of_captures == Float::INFINITY

      wrap_expressions_callbacks = {}
      wrap_expressions_callbacks[:before_all]  = options.fetch :before_all,  -> { "$SiB.filename = #{filename.inspect}; $SiB.max_line_captures = #{number_of_captures_as_str}; $SiB.num_lines = #{program.lines.count}; " }
      wrap_expressions_callbacks[:after_all]   = options.fetch :after_all,   -> { "" }
      wrap_expressions_callbacks[:before_each] = options.fetch :before_each, -> line_number { "(" }
      wrap_expressions_callbacks[:after_each]  = options.fetch :after_each,  -> line_number { ").tap { |v| $SiB.record_result(:inspect, #{line_number}, v) }" }
      WrapExpressions.call program, wrap_expressions_callbacks
    end
  end
end
