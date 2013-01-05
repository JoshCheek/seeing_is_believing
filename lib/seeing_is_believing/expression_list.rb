require 'open3'
require 'seeing_is_believing/syntax_analyzer'

# A lot of colouring going on in this file, maybe should extract a debugging object to contain it

class SeeingIsBelieving
  class ExpressionList
    PendingExpression = Struct.new :expression, :children do
      # coloured debug because there's so much syntax that I get lost trying to parse the output
      def inspect(debug=false)
        colour1 = colour2 = lambda { |s| s }
        colour1 = lambda { |s| "\e[30;46m#{s}\e[0m" } if debug
        colour2 = lambda { |s| "\e[37;46m#{s}\e[0m" } if debug
        "#{colour1['PE(']}#{colour2[expression.inspect]}#{colour1[',' ]}#{colour2[children.inspect]}#{colour1[')']}"
      end
    end

    def initialize(options)
      self.debug_stream = options.fetch :debug_stream, $stdout
      self.should_debug = options.fetch :debug, false
      self.generator    = options.fetch :generator
      self.on_complete  = options.fetch :on_complete
      self.list         = []
      @line_number      = 0
    end

    def call
      expression = nil
      begin
        generate
        expression = reduce_expressions
      end until list.empty?
      expression
    end

    private

    attr_accessor :debug_stream, :should_debug, :generator, :on_complete, :list

    def generate
      @line_number += 1
      expression = generator.call
      debug { "GENERATED: #{expression.inspect}, ADDING IT TO #{inspected_list}" }
      list << PendingExpression.new(expression, [])
    end

    def inspected_list
      "[#{list.map { |pe| pe.inspect debug? }.join(', ')}]"
    end

    def debug?
      @should_debug
    end

    def debug
      @debug_stream.puts yield if debug?
    end

    def reduce_expressions
      list.size.times do |i|
        expression = list[i..-1].map(&:expression) # uhm, should this expression we are checking for validity consider the children?
                                .join("\n")        # must use newline otherwise can get expressions like `a\\+b` that should be `a\\\n+b`, former is invalid
        return if children_will_never_be_valid? expression
        next unless valid_ruby? expression
        result = on_complete.call(list[i].expression,
                                  list[i].children,
                                  list[i+1..-1].map { |pe| [pe.expression, pe.children] }.flatten, # hmmm, not sure this is really correct, but it allows it to work for my use cases
                                  @line_number)
        self.list = list[0, i]
        list[i-1].children << result unless list.empty?
        debug { "REDUCED: #{result.inspect}, LIST: #{inspected_list}" }
        return result
      end
    end

    def valid_ruby?(expression)
      valid = SyntaxAnalyzer.valid_ruby? expression
      debug { "#{valid ? "\e[31mIS NOT VALID:" : "\e[32mIS VALID:"}: #{expression.inspect}\e[0m" }
      valid
    end

    def children_will_never_be_valid?(expression)
      SyntaxAnalyzer.unclosed_string?(expression)
    end
  end
end
