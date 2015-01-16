require 'seeing_is_believing/hash_struct'

RSpec.describe SeeingIsBelieving::HashStruct do
  let(:klass) { described_class.anon }

  def eq!(expected, actual, *message)
    expect(actual).to eq(expected), *message
  end

  def neq!(expected, actual, *message)
    expect(actual).to_not eq(expected), *message
  end

  def raises!(*exception_class_and_matcher, &block)
    expect(&block).to raise_error(*exception_class_and_matcher)
  end

  def include!(needle, haystack)
    expect(haystack).to include needle
  end

  def ninclude!(needle, haystack)
    expect(haystack).to_not include needle
  end

  describe 'declaration' do
    describe 'attributes' do
      specify 'can be individually declared, providing a default value or init block using .attribute' do
        eq! 1, klass.attribute(:a,   1 ).new.a
        eq! 2, klass.attribute(:b) { 2 }.new.b
      end

      specify 'the block value is not cached' do
        klass.attribute(:a,   "a" ).new.a << "-modified"
        eq! "a-modified", klass.new.a

        klass.attribute(:b) { "b" }.new.b << "-modified"
        eq! "b",          klass.new.b
      end

      specify 'can be group declared with a default value using .attributes(hash)' do
        klass.attributes a: 1, b: 2
        eq! 1, klass.new.a
        eq! 2, klass.new.b
      end

      specify 'can omit a default if they are initialized with one' do
        klass.attribute :a
        eq! 1, klass.new(a: 1).a
        raises!(ArgumentError, /:a/) { klass.new }
      end

      specify 'can group declare uninitialized attributes with .attributes(*names)' do
        klass.attributes(:a, :b)
        eq! 1, klass.new(a: 1, b: 2).a
        raises!(ArgumentError, /:b/) { klass.new a: 1 }
      end
    end

    describe 'predicates are attributes which' do
      specify 'can be individually declared with .predicate' do
        eq! 1, klass.predicate(:a,   1 ).new.a
        eq! 2, klass.predicate(:b) { 2 }.new.b
      end
      specify 'can be group declared with .predicates' do
        klass.predicates a: 1, b: 2
        eq! 1, klass.new.a
        eq! 2, klass.new.b
      end
      specify 'can omit a default if they are initialized with one' do
        klass.predicate :a
        eq! true, klass.new(a: 1).a?
        raises!(ArgumentError, /:a/) { klass.new }
      end
      specify 'can group declare uninitialized attributes with .attributes(*names)' do
        klass.predicates(:a, :b)
        eq! true, klass.new(a: 1, b: 2).a?
        raises!(ArgumentError, /:b/) { klass.new a: 1 }
      end
    end

    describe 'conflicts' do
      it 'raises if you double-declare an attribute' do
        klass.attribute :a, 1
        raises!(ArgumentError) { klass.attribute :a, 2 }
        raises!(ArgumentError) { klass.predicate :a, 3 }
        raises!(ArgumentError) { klass.attributes a: 4 }
        raises!(ArgumentError) { klass.predicates a: 5 }
        eq! 1, klass.new.a

        klass.predicate :b, 1
        raises!(ArgumentError) { klass.attribute :b, 2 }
        raises!(ArgumentError) { klass.predicate :b, 3 }
        raises!(ArgumentError) { klass.attributes b: 4 }
        raises!(ArgumentError) { klass.predicates b: 5 }
        eq! 1, klass.new.b
      end
    end

    describe '.attribute / .attributes / .predicate / .predicates' do
      specify 'raise if a key is not a symbol (you shouldn\'t be dynamically creating this class with strings)' do
        raises!(ArgumentError) { klass.attribute 'a', 1 }
        raises!(ArgumentError) { klass.predicate 'b', 1 }
        raises!(ArgumentError) { klass.attributes 'c' => 1 }
        raises!(ArgumentError) { klass.predicates 'd' => 1 }
      end
    end
  end

  describe 'anonymous subclasses try to be generally terse and useful to be valid replacements over Struct' do
    specify '.anon / .for / .for? return a subclass of HashStruct' do
      klass = described_class.anon
      neq! described_class, klass
      eq!  described_class, klass.superclass

      klass = described_class.for
      neq! described_class, klass
      eq!  described_class, klass.superclass

      klass = described_class.for?
      neq! described_class, klass
      eq!  described_class, klass.superclass
    end

    specify '.anon / .for / .for? take blocks which get class_eval\'d' do
      klass = described_class.anon { def a; 1 end }
      eq!  1, klass.new.a

      klass = described_class.for { def b; 2 end }
      eq!  2, klass.new.b

      klass = described_class.for? { def c; 3 end }
      eq!  3, klass.new.c
    end

    specify '.for? passes its args to .predicates' do
      klass = described_class.for?(:a, b: 3)
      eq! 1,     klass.new(a: 1).a
      eq! 3,     klass.new(a: 1).b
      eq! true,  klass.new(a: 1).b?
      eq! false, klass.new(a: 1, b: nil).b?
    end

    specify '.for passes its args to .attributes' do
      klass = described_class.for(:a, b: 3)
      eq! 1,     klass.new(a: 1).a
      eq! 3,     klass.new(a: 1).b
      raises!(NoMethodError) { klass.new(a: 1).b? }
    end

    specify 'subclasses retain their parents attributes without them mixing' do
      parent = klass.for(a: 1)
      child  = parent.for(b: 2)
      eq! 1, child.new.a
      eq! 2, child.new.b
      eq! 1, parent.new.a
      raises!(NoMethodError) { parent.new.b }
    end

    specify 'subclasses can override their parents attributes' do
      c1 = klass.for(a: 1, b: 1, c: 1)
      c2 = c1.for(a: 2, b: 2)
      c3 = c2.for(a: 3)
      eq! 3, c3.new.a
      eq! 2, c3.new.b
      eq! 1, c3.new.c

      eq! 2, c2.new.a
      eq! 2, c2.new.b
      eq! 1, c2.new.c

      eq! 1, c1.new.a
      eq! 1, c1.new.b
      eq! 1, c1.new.c

      raises!(ArgumentError) { c2.attribute :a } # still can't redefine their own
    end

    specify '.inspect returns HashStruct.anon when it does not have a name' do
      expect(klass.anon.inspect).to eq 'HashStruct.anon'

      named_class = klass.anon
      allow(named_class).to receive(:name).and_return("SomeClass")
      expect(named_class.inspect).to eq 'SomeClass'
    end
  end


  describe 'use' do
    describe 'initialization' do
      it 'sets all values to their defaults, calling the init blocks at that time, with the instance' do
        calls = []
        klass.attribute(:a) { calls << :a; 1 }.attribute(:b, 2).attributes(c: 3)
             .predicate(:d) { calls << :d; 4 }.predicate(:e, 5).predicates(f: 6)
             .attribute(:g) { |i| i.b + i.c }
             .predicate(:h) { |i| i.e + i.f }
        eq! [], calls
        instance = klass.new
        eq! [:a, :d], calls
        eq! 1,  instance.a
        eq! 2,  instance.b
        eq! 3,  instance.c
        eq! 4,  instance.d
        eq! 5,  instance.e
        eq! 6,  instance.f
        eq! 5,  instance.g
        eq! 11, instance.h
        eq! [:a, :d], calls
      end
      it 'accepts a hash of any declard attribute overrides' do
        instance = klass.attributes(a: 1, b: 2).new(a: 3)
        eq! 3, instance.a
        eq! 2, instance.b
      end
      it 'accepts string and symbol keys' do
        instance = klass.attributes(a: 1, b: 2).new(a: 3, 'b' => 4)
        eq! 3, instance.a
        eq! 4, instance.b
      end
      it 'raises if initialized with attributes it doesn\'t know' do
        klass.attribute :a, 1
        raises!(KeyError) { klass.new b: 2 }
      end
      it 'raises an ArgumentError if all its values aren\'t initialized between defaults and init hash' do
        klass.attribute :a, 1
        klass.attribute :b
        klass.new(b: 1)
        raises!(ArgumentError) { klass.new }
      end
      it 'won\'t raise until after a provided block is invoked' do
        klass.attributes(:a, :b)
        eq! 1, klass.new(b: 1) { |i| i.a = 1 }.a
        eq! nil, klass.new(b: 1) { |i| i.a = nil }.a
        raises!(ArgumentError) { klass.new {} }
        klass.new(b: 2) { |instance|
          raises!(ArgumentError) { instance.a }
          raises!(ArgumentError) { instance[:a] }
          instance.a = 1
          eq! 1, instance.a
          eq! 1, instance[:a]
          eq! 2, instance.b
        }
      end
      it 'gives you a helpful message when you pass it a non-enumerable argument (ie when used to normal Struct)' do
        klass.attributes(a: 1)
        expect { klass.new 1 }.to raise_error ArgumentError, /\b1\b/
      end
    end

    describe '#[] / #[]=' do
      specify 'get/set an attribute using string or symbol' do
        instance = klass.attribute(:a, 1).new
        eq! 1, instance[:a]
        eq! 1, instance['a']
        instance[:a] = 2
        eq! 2, instance[:a]
        eq! 2, instance['a']
        instance['a'] = 3
        eq! 3, instance[:a]
        eq! 3, instance['a']
      end
      specify 'raise if given a key that is not an attribute' do
        instance = klass.attribute(:a, 1).new
        instance[:a]
        raises!(KeyError) { instance[:b] }

        instance[:a] = 2
        raises!(KeyError) { instance[:b] = 2 }
      end
    end

    describe '#fetch' do
      let(:instance) { klass.attributes(a: :value).new }
      it 'returns the key if it exists' do
        eq! :value, instance.fetch(:a)
      end
      it 'accepts a second argument, which it just ignores' do
        eq! :value, instance.fetch(:a, :default)
      end
      it 'raises a KeyError if the key doesn\'t exist, regardless of the second argument or a default block -- point of this is that you know what\'s in the hashes' do
        raises!(KeyError) { instance.fetch(:b, :default) }
        raises!(KeyError) { instance.fetch(:b) { :default } }
      end
    end

    describe 'setter, getter, predicate' do
      specify '#<attr>  gets the attribute' do
        eq! 1, klass.attribute(:a, 1).new.a
      end
      specify '#<attr>= sets the attribute' do
        instance = klass.attribute(:a, 1).new
        eq! 1, instance.a
        instance.a = 2
        eq! 2, instance.a
      end
      specify '#<attr>? is an additional predicate getter' do
        klass.attribute(:a, 1).attributes(b: 2)
             .predicate(:c, 3).predicates(d: 4)
        instance = klass.new
        raises!(NoMethodError) { instance.a? }
        raises!(NoMethodError) { instance.b? }
        instance.c?
        instance.d?
      end
      specify '#<attr>? returns true or false based on what the value would do in a conditional' do
        instance = klass.predicates(nil: nil, false: false, true: true, object: Object.new).new
        eq! false, instance.nil?
        eq! false, instance.false?
        eq! true,  instance.true?
        eq! true,  instance.object?
      end
    end

    # include a fancy inspect with optional color?, optional width? tabular format?
    describe 'inspection' do
      class Example < described_class
        attributes a: 1, b: "c"
      end
      it 'inspects prettily' do
        eq! '#<HashStruct Example: {a: 1, b: "c"}>', Example.new.inspect
        klass.attributes(c: /d/)
        eq! '#<HashStruct.anon: {c: /d/}>', klass.new.inspect
      end
    end

    describe 'pretty printed' do
      require 'pp'

      def pretty_inspect(attrs)
        klass.for(attrs.keys.map &:intern)
             .new(attrs)
             .pretty_inspect
             .chomp
      end

      class EmptySubclass < SeeingIsBelieving::HashStruct
      end
      it 'begins with instantiation of the class or HashStruct.anon { ... }.new(' do
        eq! "HashStruct.anon { ... }.new()", klass.new.pretty_inspect.chomp
        eq! "EmptySubclass.new()", EmptySubclass.new.pretty_inspect.chomp
      end

      it "uses 1.9 hash syntax" do
        include! "key:", pretty_inspect(key: :value)
        ninclude! "=>",  pretty_inspect(key: :value)
      end
      it "puts the key/value pairs inline when they are short" do
        include! "(key: :value)", pretty_inspect(key: :value)
      end
      it "puts the key/value pairs on their own indented line, when they are long" do
        include! "(\n  #{"k"*30}: \"#{"v"*30}\"\n)",
                 pretty_inspect("k"*30 => "v"*30)
      end
      it "indents the key/value pairs" do
        attrs = {"a"*30 => "b"*30,
                 "c"*30 => "d"*30}
        include! "(\n"\
                 "  #{"a"*30}: \"#{"b"*30}\",\n"\
                 "  #{"c"*30}: \"#{"d"*30}\"\n"\
                 ")",
                 pretty_inspect(attrs)
      end
      it "breaks the value onto an indented next line when long" do
        include! "  #{"a"*50}:\n    \"#{"b"*50}\"",
                 pretty_inspect("a"*50 => "b"*50)
      end
      it "pretty prints the value" do
        ary = [*1..25]
        include! "  k:\n    [#{ary.map { |n| "     #{n}"}.join(",\n").lstrip}]",
                 pretty_inspect(k: ary)
      end
    end

    describe '#to_hash / #to_h' do
      it 'returns a dup\'d Ruby hash of the internal attributes' do
        klass.attributes(a: 1, b: 2)
        eq!({a: 1, b: 3}, klass.new(b: 3).to_hash)
        eq!({a: 3, b: 2}, klass.new(a: 3).to_h)

        instance = klass.new
        instance.to_h[:a] = :injected
        eq!({a: 1, b: 2}, instance.to_h)
      end
    end

    describe 'merge' do
      before { klass.attributes(a: 1, b: 2, c: 3) }

      it 'returns a new instance with the merged values overriding its own' do
        merged = klass.new(b: -2).merge c: -3
        eq! klass, merged.class
        eq!({a: 1, b: -2, c: -3}, merged.to_h)
      end

      it 'does not modify the LHS or RHS' do
        instance   = klass.new b: -2
        merge_hash = {c: -3}
        instance.merge merge_hash
        eq!({a: 1, b: -2, c: 3}, instance.to_h)
        eq!({c: -3}, merge_hash)
      end
    end

    describe 'enumerability' do
      it 'is enumerable, iterating over each attribute(as symbol)/value pair' do
        klass.attributes(a: 1, b: 2)
        eq! [[:a, 1], [:b, 2]], klass.new.to_a
        eq! "a1b2", klass.new.each.with_object("") { |(k, v), s| s << "#{k}#{v}" }
      end
    end

    describe 'keys/values' do
      specify 'keys returns an array of symbols of all its attributes' do
        eq! [:a, :b], klass.attributes(a: 1, b: 2).new(b: 3).keys
      end
      specify 'values returns an array of symbol values' do
        eq! [1, 3], klass.attributes(a: 1, b: 2).new(b: 3).values
      end
    end

    describe '#key? / #has_key? / #include? / #member?' do
      specify 'return true iff the key (symbolic or string) is an attribute' do
        instance = klass.attributes(a: 1, b: nil, c: false).new
        [:key?, :has_key?, :include?, :member?].each do |predicate|
          [:a, :b, :c, 'a', 'b', 'c'].each do |key|
            eq! true, instance.__send__(predicate, key), "#{instance.inspect}.#{predicate}(#{key.inspect}) returned false"
          end
          eq! false, instance.__send__(predicate, :d)
          eq! false, instance.__send__(predicate, 'd')
          eq! false, instance.__send__(predicate, /b/)
        end
      end
    end

    describe '#==' do
      it 'is true if the RHS\'s to_h has the same key/value pairs' do
        instance1 = described_class.for(a: 1, b: 2).new
        instance2 = described_class.for(a: 1, b: 2).new
        instance3 = described_class.for(a: 1, c: 2).new
        eq! instance1, instance1
        eq! instance1, instance2
        eq! instance1, {a: 1, b: 2}
        instance2.b = 3
        neq! instance1, instance2
        neq! instance1, instance3
        neq! instance1, {a: 1}
        neq! instance1, {a: 1, b: 2, c: 1}
        eq! false, 1.respond_to?(:to_h)
        eq! false, 1.respond_to?(:to_hash)
        neq! instance1, 1
      end
    end

    specify '#eql? is an alias of #==' do
      instance1 = described_class.for(a: 1, b: 2).new
      instance2 = described_class.for(a: 1, b: 2).new
      expect(instance1).to eql instance2
    end

    specify '#hash is the same as Hash#hash' do
      instance = described_class.for(a: 1, b: 2).new
      eq! instance.hash, {a: 1, b: 2}.hash
    end

    it 'can be used in set methods, e.g. as a hash key' do
      instance1 = described_class.for(a: 1, b: 2).new
      instance2 = described_class.for(a: 1, b: 2).new
      eq! [], [instance1] - [instance2]
      eq! [], [instance2] - [instance1]
      eq! [], [instance1] - [{a: 1, b: 2}]
      eq! [], [{a: 1, b: 2}] - [instance1]
      eq! [instance1], [instance1, instance2].uniq
    end

    specify 'accepts nil as a value (common edge case)' do
      klass.attributes default_is_nil: nil, default_is_1: 1

      # default init block
      instance = klass.new
      eq! nil, instance.default_is_nil
      eq! nil, instance[:default_is_nil]

      # overridden on initialization
      instance = klass.new default_is_1: nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set with setter
      instance = klass.new
      instance.default_is_1 = nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set with []= and symbol
      instance = klass.new
      instance[:default_is_1] = nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set with []= and string
      instance = klass.new
      instance['default_is_1'] = nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set after its been set to nil
      instance = klass.new
      instance[:default_is_nil] = nil
      instance[:default_is_nil] = nil
      instance.default_is_nil   = nil
      instance.default_is_nil   = nil
    end
  end
end
