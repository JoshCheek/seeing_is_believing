require 'seeing_is_believing/strict_hash'

RSpec.describe SeeingIsBelieving::StrictHash do
  let(:klass) {
    klass = Class.new(described_class)
    class << klass
      public :attribute
      public :attributes
      public :predicate
      public :predicates
    end
    klass
  }

  def eq!(expected, actual)
    expect(expected).to eq actual
  end

  def raises!(*exception_class_and_matcher, &block)
    expect(&block).to raise_error(*exception_class_and_matcher)
  end

  describe 'declaration' do
    describe 'attributes' do
      specify 'can be individually declared, requiring a default value or init block using .attribute' do
        eq! 1, klass.attribute(:a,   1 ).new.a
        eq! 2, klass.attribute(:b) { 2 }.new.b
        raises!(ArgumentError) { klass.attribute :c }
      end

      specify 'the block form is always called' do
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
    end

    describe 'predicates are attributes which' do
      specify 'can be individually declared with .predicate' do
        eq! 1, klass.predicate(:a,   1 ).new.a
        eq! 2, klass.predicate(:b) { 2 }.new.b
        raises!(ArgumentError) { klass.predicate :c }
      end
      specify 'can be group declared with .predicates' do
        klass.predicates a: 1, b: 2
        eq! 1, klass.new.a
        eq! 2, klass.new.b
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
      specify 'are private' do
        raises!(NoMethodError) { Class.new(described_class).attribute :a, 1 }
        eq! 1, Class.new(described_class) { attribute :a, 1 }.new.a
      end

      specify 'raise if a key is not a symbol (you shouldn\'t be dynamically creating this class with strings)' do
        raises!(ArgumentError) { klass.attribute 'a', 1 }
        raises!(ArgumentError) { klass.predicate 'b', 1 }
        raises!(ArgumentError) { klass.attributes 'c' => 1 }
        raises!(ArgumentError) { klass.predicates 'd' => 1 }
      end

      specify 'accept nil as a value (common edge case)' do
        eq! nil, klass.attribute(:a, nil).new.a
      end
    end
  end


  describe 'use' do
    describe 'initialization' do
      it 'sets all values to their defaults, calling the init blocks at that time'
      it 'accepts a hash of any declard attribute overrides'
      it 'accepts string and symbol keys'
      it 'raises if given any attributes it doesn\'t know'
    end

    describe '#[] / #[]=' do
      specify 'get/set an attribute'
      specify 'raise if given a key that is not an attribute'
      specify 'accepts string and symbol keys'
    end

    describe 'setter, getter, predicate' do
      specify '#<attr>  gets the attribute'
      specify '#<attr>= sets the attribute'
      specify '#<attr>? is an additional predicate getter'
      specify '#<attr>? always returns true or false'
    end

    describe 'inspection' do
      it 'inspects prettily' # optional color?, optional width? tabular format?
    end

    describe '#to_hash / #to_h' do
      it 'returns a dup\'d Ruby hash of the internal attributes'
    end

    describe 'merge' do
      it 'returns a new instance with the merged values overriding its own'
    end

    describe 'enumerability' do
      it 'is enumerable, iterating over each attribute(as symbol)/value pair'
      it 'iterates in the order the attributes were declared'
    end

    describe 'keys/values' do
      specify 'keys returns an array of symbols of all its attributes'
      specify 'values returns an array of symbol values'
    end

    describe '#key? / #has_key? / #include? / #member?' do
      specify 'return true iff the key (symbolic or string) is an attribute'
    end
  end
end
