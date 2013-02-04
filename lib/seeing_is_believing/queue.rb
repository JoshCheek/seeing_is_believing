class SeeingIsBelieving
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

    def permanently_empty?
      @permanently_empty
    end
  end
end
