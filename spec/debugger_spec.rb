require 'spec_helper'
require 'seeing_is_believing/debugger'
require 'stringio'

RSpec.describe SeeingIsBelieving::Debugger do
  let(:stream) { StringIO.new }

  specify 'is enabled when given a stream' do
    expect(described_class.new(stream: nil)).to_not be_enabled
    expect(described_class.new(stream: stream)).to be_enabled
  end

  specify 'colour is disabled by default' do
    expect(described_class.new).to_not be_coloured
    expect(described_class.new(colour: false)).to_not be_coloured
    expect(described_class.new(colour:  true)).to be_coloured
  end

  context 'when given a stream' do
    it 'prints the the context and the value of the block' do
      described_class.new(stream: stream).context('C') { 'V' }
      expect(stream.string).to eq "C:\nV\n"
    end

    it 'colours the context when colour is set to true' do
      described_class.new(stream: stream, colour: true).context('C') { 'V' }
      expect(stream.string).to eq "#{described_class::CONTEXT_COLOUR}C:#{described_class::RESET_COLOUR}\nV\n"
    end
  end

  context 'when not given a stream' do
    it 'prints nothing' do
      described_class.new.context('C') { 'V' }
      expect(stream.string).to be_empty
    end

    it 'does not evaluate the blocks' do
      described_class.new.context('C') { fail }
    end
  end

  specify '::Null is a disabled debugger' do
    expect(described_class::Null).to_not be_enabled
  end
end
