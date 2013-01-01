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
      puts "ADDING: #{expression.inspect} TO: #{@list.inspect}"
      @line_number += 1
      @list << PendingExpression.new(expression, options[:on_complete], [])
      reduce_expressions options[:generate]
    end

    def empty?
      @list.empty?
    end

    private

    # :(
    def reduce_expressions(generate)
      expressions = @list.map(&:expression)
      @list.size.times do |i|
        expression = expressions.join "\n" # must use newline otherwise can get expressions like `a\\+b` that should be `a\\\n+b`, former is invalid
        unless valid_ruby? expression
          expressions.shift
          next
        end
        result = @list[i].on_complete.call(@list[i].expression,
                                           @list[i].children,
                                           @list[i+1..-1].map(&:expression),
                                           @line_number)
        if i.zero?
          @list = []
        else
          @list = @list[0..i-1]
        end
        @list[i-1].children << result unless @list.empty?
        puts "RESULT: #{result.inspect}, #{@list.inspect}"
        return result
      end
      generate.call
    end

    def valid_ruby?(expression)
      Open3.capture3('ruby -c', stdin_data: expression).last.success?
    end
  end
end


#     @line_number += 1

#     if previous_expressions.empty? && valid_ruby?(line)
#       record_yahself line, @line_number
#     elsif previous_expressions.empty?
#       next_expression = get_next_expression [line]
#       record_yahself next_expression, @line_number
#     elsif completes_previous_expression?(previous_expressions, line)
#       previous_expression previous_expressions, line
#     end
#   end

#   def self.previous_expression(previous_expressions,

#   def any_valid?(previous_expressions, current_expression)
#     puts "PREVIOUS EXPRESSIONS: #{previous_expressions.inspect}"
#     expression = current_expression
#     index = previous_expressions.size - 1
#     until index == -1
#       expression = previous_expressions[index] + expression
#       return true if valid_ruby? expression
#       index -= 1
#     end
#     false
#   end

