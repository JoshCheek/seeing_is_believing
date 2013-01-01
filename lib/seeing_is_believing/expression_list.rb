require 'open3'

class SeeingIsBelieving
  class ExpressionList
    PendingExpression = Struct.new :expression, :on_complete, :children do
      def inspect(debug=false)
        colour1 = colour2 = lambda { |s| s }
        colour1 = lambda { |s| "\e[30;46m#{s}\e[0m" } if debug
        colour2 = lambda { |s| "\e[37;46m#{s}\e[0m" } if debug
        "#{colour1['PE(']}#{colour2[expression.inspect]}#{colour1[',' ]}#{colour2[children.inspect]}#{colour1[')']}"
      end
    end

    def initialize(debug=false, debug_stream=$stdout)
      @debug_stream = debug_stream
      @should_debug = debug
      @line_number  = 0
      @list         = []
    end

    def push(expression, options)
      debug? && debug("PUSHING: #{expression.inspect} ONTO #{@list.inspect}")
      @line_number += 1
      @list << PendingExpression.new(expression, options[:on_complete], [])
      reduce_expressions options[:generate]
    end

    private

    def debug?
      @should_debug
    end

    def debug(message)
      @debug_stream.puts message
    end

    # O.o
    def reduce_expressions(generate)
      @list.size.times do |i|
        expression = @list[i..-1].map(&:expression).join "\n" # must use newline otherwise can get expressions like `a\\+b` that should be `a\\\n+b`, former is invalid
        next unless valid_ruby? expression
        result = @list[i].on_complete.call(@list[i].expression,
                                           @list[i].children,
                                           @list[i+1..-1].map(&:expression),
                                           @line_number)
        @list = @list[0, i]
        @list[i-1].children << result unless @list.empty?
        debug? && debug("RESULT: #{result.inspect}, LIST: [#{@list.map { |e| e.inspect debug? }.join(', ')}]")
        return result
      end
      generate.call
    end

    def valid_ruby?(expression)
      Open3.capture3('ruby -c', stdin_data: expression).last.success?
    end
  end
end
