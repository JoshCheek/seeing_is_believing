class SeeingIsBelieving
  class Queue

    attr_accessor :value_generator

    def initialize(&value_generator)
      self.value_generator = value_generator
    end

    def dequeue
      return if permanently_empty?
      if @next_value
        peek.tap { @next_value = nil }
      else
        peek && dequeue
      end
    end

    def peek
      return if permanently_empty?
      @next_value ||= begin
                        value = value_generator.call
                        @permanently_empty = true unless value
                        value
                      end
    end

    def empty?
      permanently_empty? || peek.nil?
    end

    def permanently_empty?
      @permanently_empty
    end
  end
end
