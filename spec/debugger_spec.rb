require 'seeing_is_believing/debugger'
require 'stringio'

describe SeeingIsBelieving::Debugger do
  let(:stream) { StringIO.new }

  specify 'is enabled when given a stream' do
    described_class.new(stream: nil).should_not be_enabled
    described_class.new(stream: stream).should be_enabled
  end

  specify 'colour is disabled by default' do
    described_class.new.should_not be_coloured
    described_class.new(colour: false).should_not be_coloured
    described_class.new(colour:  true).should be_coloured
  end

  context 'when given a stream' do
    it 'prints the the context and the value of the block' do
      described_class.new(stream: stream).context('C') { 'V' }
      stream.string.should == "C:\nV\n"
    end

    it 'colours the context when colour is set to true' do
      described_class.new(stream: stream, colour: true).context('C') { 'V' }
      stream.string.should == "#{described_class::CONTEXT_COLOUR}C:#{described_class::RESET_COLOUR}\nV\n"
    end
  end

  context 'when not given a stream' do
    it 'prints nothing' do
      described_class.new.context('C') { 'V' }
      stream.string.should be_empty
    end

    it 'does not evaluate the blocks' do
      described_class.new.context('C') { fail }
    end
  end
end
