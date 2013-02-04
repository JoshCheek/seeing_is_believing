class SeeingIsBelieving
  class Queue
    class While
      attr_accessor :queue, :conditional

      def initialize(queue, &conditional)
        self.queue, self.conditional = queue, conditional
      end

      def each(&block)
        block.call queue.dequeue while !queue.empty? && conditional.call(queue.peek)
      end
    end
  end

  class Queue
    attr_accessor :value_generator

    def initialize(&value_generator)
      self.value_generator = value_generator
    end

    def dequeue
      return if permanently_empty?
      peek.tap { @next_value = nil }
    end

    def peek
      return if permanently_empty?
      @next_value ||= value_generator.call.tap { |value| @permanently_empty = value.nil? }
    end

    def empty?
      permanently_empty? || peek.nil?
    end

    def each(&block)
      block.call dequeue until empty?
    end

    def until(&block)
      While.new(self) { |*args| !block.call(*args) }
    end

    def while(&block)
      While.new self, &block
    end

    private

    def permanently_empty?
      @permanently_empty
    end
  end
end
