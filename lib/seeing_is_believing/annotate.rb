require 'seeing_is_believing/wrap_expressions'
class SeeingIsBelieving
  module Annotate
    # TODO: this is not annotation.... this is part of wrapping
    def self.call(program, filename, max_line_captures, options={})
      # TODO: much of this is duplicated in annotate_marked_lines
      max_line_captures_as_str = max_line_captures.inspect
      max_line_captures_as_str = 'Float::INFINITY' if max_line_captures == Float::INFINITY

      wrap_expressions_callbacks = {}
      wrap_expressions_callbacks[:before_all]  = options.fetch :before_all,  -> { "$SiB.record_ruby_version RUBY_VERSION;"\
                                                                                  "$SiB.record_sib_version #{VERSION.inspect};"\
                                                                                  "$SiB.record_filename #{filename.inspect};"\
                                                                                  "$SiB.record_max_line_captures #{max_line_captures_as_str};"\
                                                                                  "$SiB.num_lines = #{program.lines.count}; " }
      wrap_expressions_callbacks[:after_all]   = options.fetch :after_all,   -> { "" }
      wrap_expressions_callbacks[:before_each] = options.fetch :before_each, -> line_number { "(" }
      wrap_expressions_callbacks[:after_each]  = options.fetch :after_each,  -> line_number { ").tap { |v| $SiB.record_result(:inspect, #{line_number}, v) }" }
      WrapExpressions.call program, wrap_expressions_callbacks
    end
  end
end
