class SeeingIsBelieving
  class StrictHash
    class << self

      private

      AttributeNotProvided = Module.new

      def init_blocks
        @init_blocks ||= {}
      end

      def attribute(name, value=AttributeNotProvided, &init_block)
        value == AttributeNotProvided && !init_block and
          raise ArgumentError, "Must provide a default value for #{name.inspect}"
        init_blocks.key? name and
          raise ArgumentError, "#{name} was already defined"
        name.kind_of? Symbol or
          raise ArgumentError, "#{name.inspect} should have been a symbol"

        init_block ||= lambda { value }

        init_blocks[name] = init_block
        define_method(name, &init_block)
        self
      end

      def attributes(pairs={})
        pairs.each { |key, value| attribute key, value }
        self
      end

      def predicate(name, *rest, &b)
        attribute name, *rest, &b
      end

      def predicates(pairs)
        attributes pairs
      end
    end
  end
end
