class SeeingIsBelieving
  HashStruct = Class.new

  class << HashStruct
    NoDefault = Module.new

    def init_blocks
      @init_blocks ||= {}
    end

    def attribute(name, value=NoDefault, &init_block)
      init_blocks.key?(name) && raise(ArgumentError, "#{name} was already defined")
      name.kind_of?(Symbol)  || raise(ArgumentError, "#{name.inspect} should have been a symbol")

      init_block ||= lambda do |hash_struct|
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
      names_or_pairs.each do |norp|
        case norp
        when Symbol then attribute(norp)
        else norp.each { |name, default| attribute name, default }
        end
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

    def anon(&block)
      Class.new self, &block
    end

    def for(*attributes_args, &block)
      anon(&block).attributes(*attributes_args)
    end

    def for?(*predicate_args, &block)
      anon(&block).predicates(*predicate_args)
    end
  end

  class HashStruct
    def self.inspect
      name || "HashStruct.anon"
    end

    # This could support dynamic attributes very easily
    # ie they are calculated, but appear as a value (e.g. in to_hash)
    # not sure how to deal with the fact that they could be assigned, though
    class Attr
      def initialize(instance, value=nil, &block)
        @instance = instance
        @block    = block if block
        @value    = value unless block
      end
      def value
        return @value if defined? @value
        @value = @block.call(@instance)
      end
    end

    # The aggressivenes of this is kind of annoying when you're trying to build up a large hash of values
    # maybe new vs new! one validates arg presence,
    # maybe a separate #validate! method for that?
    def initialize(initial_values={}, &initializer)
      initial_values.respond_to?(:each) ||
        raise(ArgumentError, "#{self.class.inspect} expects to be initialized with a hash-like object, but got #{initial_values.inspect}")
      @attributes = self
        .class
        .ancestors
        .take_while { |ancestor| ancestor != HashStruct }
        .map(&:init_blocks)
        .reverse
        .inject({}, :merge)
        .each_with_object({}) { |(name, block), attrs| attrs[name] = Attr.new(self, &block) }
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
      @attributes[internalize! key] = Attr.new(self, value)
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
      classname = self.class.name ? "HashStruct #{self.class.name}" : self.class.inspect
      inspected_attrs = map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      "#<#{classname}: {#{inspected_attrs}}>"
    end

    def pretty_print(pp)
      pp.text self.class.name || 'HashStruct.anon { ... }'
      pp.text '.new('
      pp.group 2 do
        pp.breakable '' # place inside so that if we break, we are indented
        last_key = keys.last
        each do |key, value|
          # text-space-value, or text-neline-indent-value
          pp.text "#{key}:"
          pp.group 2 do
            pp.breakable " "
            pp.pp value
          end
          # all lines end in a comma, and can have a newline, except the last
          pp.comma_breakable unless key == last_key
        end
      end
      pp.breakable ''
      pp.text ')'
    end

    def key?(key)
      key.respond_to?(:to_sym) && @attributes.key?(key.to_sym)
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
    alias eql? ==

    # this might be pretty expensive
    def hash
      to_h.hash
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
