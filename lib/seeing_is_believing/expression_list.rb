require 'open3'

class SeeingIsBelieving
  class ExpressionList
    PendingExpression = Struct.new :expression, :on_complete, :children do
      def inspect
        "PE(#{expression.inspect}, #{children.inspect})"
      end
    end
    def initialize
      @line_number = 0
      @list = []
    end

    def push(expression, options)
      @line_number += 1
      @list << PendingExpression.new(expression, options[:on_complete], [])
      reduce_expressions options[:generate]
    end

    private

    # O.o
    def reduce_expressions(generate)
      expressions = @list.map(&:expression)
      @list.size.times do |i|
        expression = expressions.join "\n" # must use newline otherwise can get expressions like `a\\+b` that should be `a\\\n+b`, former is invalid
        next expressions.shift unless valid_ruby? expression
        result = @list[i].on_complete.call(@list[i].expression,
                                           @list[i].children,
                                           @list[i+1..-1].map(&:expression),
                                           @line_number)
        @list = @list[0, i]
        @list[i-1].children << result unless @list.empty?
        return result
      end
      generate.call
    end

    def valid_ruby?(expression)
      Open3.capture3('ruby -c', stdin_data: expression).last.success?
    end
  end
end
