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
      define_method(name) { @attributes[name] }
      define_method(:"#{name}=") { |val| @attributes[name] = val }

      self
    end

    def attributes(pairs={})
      pairs.each { |key, value| attribute key, value }
      self
    end

    def predicate(name, *rest, &b)
      attribute name, *rest, &b
      define_method(:"#{name}?") { !!@attributes[name] }
      self
    end

    def predicates(pairs)
      pairs.each { |key, value| predicate key, value }
      self
    end
  end

  class StrictHash
    Uninitialized = Module.new
    def initialize(initial_values={})
      uninitialized_key_value_pairs = self.class.init_blocks.map { |name, _| [name, Uninitialized] }
      @attributes = Hash[uninitialized_key_value_pairs]
      initial_values.each { |key, value| self[key] = value }
      self.class.init_blocks.each do |name, init_block|
        self[name] = init_block.call if self[name] == Uninitialized
      end
    end

    def [](key)
      @attributes[internalize key]
    end

    def []=(key, value)
      @attributes[internalize key] = value
    end

    def fetch(key, ignored=nil)
      self[key]
    end

    def to_hash
      @attributes.dup
    end
    alias to_h to_hash

    def merge(overrides)
      self.class.new(@attributes.merge overrides)
    end

    include Enumerable
    def each(&block)
      return to_enum :each unless block
      @attributes.each do |key, value|
        block.call(key, value)
      end
    end

    def keys
      @attributes.keys
    end

    def values
      @attributes.values
    end

    def inspect
      classname  = self.class.name || 'subclass'
      attributes = map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      "#<StrictHash #{classname}: {#{attributes}}>"
    end

    def key?(potential_key)
      internalize potential_key
      return true
    rescue KeyError
      return false
    end
    alias has_key? key?
    alias include? key? # b/c Hash does this
    alias member?  key? # b/c Hash does this

    def ==(other)
      equal?(other) || @attributes == other.to_h
    end

    private

    def internalize(key)
      internal = key.to_sym
      @attributes.key?(internal) || raise(KeyError)
      internal
    rescue NoMethodError, KeyError
      raise KeyError, "#{key.inspect} is not an attribute, should be in #{@attributes.keys.inspect}"
    end
  end
end
