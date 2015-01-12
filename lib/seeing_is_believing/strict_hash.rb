class SeeingIsBelieving
  StrictHash = Class.new

  # TODO: Do I want to support non-block form by using dup? or clone?
  # uhh.... what's the difference between dup and clone again?
  class << StrictHash
    NoDefault = Module.new

    def init_blocks
      @init_blocks ||= {}
    end

    def attribute(name, value=NoDefault, &init_block)
      init_blocks.key?(name)                       && raise(ArgumentError, "#{name} was already defined")
      name.kind_of?(Symbol)                        || raise(ArgumentError, "#{name.inspect} should have been a symbol")

      init_block ||= lambda do
        if value == NoDefault
          raise ArgumentError, "Must provide a value for #{name.inspect}"
        else
          value
        end
      end
      init_blocks[name] = init_block
      define_method(name) { self[name] }
      define_method(:"#{name}=") { |val| self[name] = val }

      self
    end

    def attributes(*names_or_pairs)
      names_or_pairs.each do |name_or_pairs|
        name = pairs = name_or_pairs
        name_or_pairs.kind_of?(Symbol) ?
          attribute(name) :
          pairs.each { |name, default| attribute name, default }
      end
      self
    end

    def predicate(name, *rest, &b)
      attribute name, *rest, &b
      define_method(:"#{name}?") { !!self[name] }
      self
    end

    def predicates(*names_or_pairs)
      names_or_pairs.each do |name_or_pairs|
        name = pairs = name_or_pairs
        name_or_pairs.kind_of?(Symbol) ?
          predicate(name) :
          pairs.each { |name, default| predicate name, default }
      end
      self
    end

    def anon(*predicate_args)
      Class.new(self).predicates(*predicate_args)
    end
  end

  class StrictHash
    class Attr
      def initialize(value=nil, &block)
        @block = block if block
        @value = value unless block
      end
      def value
        return @value if defined? @value
        @value = @block.call
      end
    end

    def initialize(initial_values={}, &initializer)
      @attributes = Hash[
        self.class.init_blocks.map { |name, block| [name, Attr.new(&block) ] }
      ]
      initial_values.each { |key, value| self[key] = value }
      initializer.call self if initializer
      each { } # access each key to see if it blows up
    end

    include Enumerable
    def each(&block)
      return to_enum :each unless block
      @attributes.keys.each do |name|
        block.call(name, self[name])
      end
    end

    def [](key)
      @attributes[internalize! key].value
    end

    def []=(key, value)
      @attributes[internalize! key] = Attr.new(value)
    end

    def fetch(key, ignored=nil)
      self[key]
    end

    def to_hash
      Hash[to_a]
    end
    alias to_h to_hash

    def merge(overrides)
      self.class.new(to_h.merge overrides)
    end

    def keys
      to_a.map(&:first)
    end

    def values
      to_a.map(&:last)
    end

    def inspect
      classname = self.class.name || 'subclass'
      inspected_attrs = map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      "#<StrictHash #{classname}: {#{inspected_attrs}}>"
    end

    def key?(potential_key)
      internalize! potential_key
      return true
    rescue KeyError
      return false
    end
    alias has_key? key?
    alias include? key? # b/c Hash does this
    alias member?  key? # b/c Hash does this

    def ==(other)
      if equal? other
        true
      elsif other.kind_of? Hash
        to_h == other
      elsif other.respond_to?(:to_h)
        to_h == other.to_h
      else
        false
      end
    end

    private

    def internalize!(key)
      internal = key.to_sym
      @attributes.key?(internal) || raise(KeyError)
      internal
    rescue NoMethodError, KeyError
      raise KeyError, "#{key.inspect} is not an attribute, should be in #{@attributes.keys.inspect}"
    end
  end
end
