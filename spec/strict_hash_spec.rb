require 'seeing_is_believing/strict_hash'

RSpec.describe SeeingIsBelieving::StrictHash do
  describe 'declaration' do
    describe 'attributes' do
      specify 'can be individually declared, requiring a default value or init block using .attribute'
      specify 'can be group declared with a default value using .attributes(hash)'
    end

    describe 'predicates' do
      specify 'are attributes'
      specify 'can be individually declared with .predicate'
      specify 'can be group declared with .predicates'
    end

    describe 'conflicts' do
      it 'raises if you double-declare an attribute'
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
      it 'is enumerable, iterating over each attribute/value pair'
      it 'iterates in the order the attributes were declared'
    end

    describe 'keys/values' do
      specify 'keys returns an array of symbols of all its attributes'
      specify 'values returns an array of symbol values'
    end
  end
end
