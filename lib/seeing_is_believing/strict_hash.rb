class SeeingIsBelieving
  StrictHash = Class.new

  class << StrictHash
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
    def initialize(initial_values={})
      @attributes = {}
      self.class.__send__(:init_blocks)
          .each { |name, init_block| @attributes[name] = init_block.call }
      initial_values.each { |key, value| self[key] = value }
    end

    def [](key)
      @attributes[internalize key]
    end

    def []=(key, value)
      @attributes[internalize key] = value
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

    private

    def internalize(key)
      internal = key.to_sym
      @attributes.key? internal or raise KeyError
      internal
    rescue NoMethodError, KeyError
      raise KeyError, "#{key.inspect} is not an attribute, should be in #{@attributes.keys.inspect}"
    end
  end
end
