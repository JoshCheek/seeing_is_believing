require 'seeing_is_believing/debugger'

describe SeeingIsBelieving::Debugger do
  specify 'the debugger is enabled by default' do
    described_class.new.should be_enabled
    described_class.new(enabled: true).should be_enabled
    described_class.new(enabled: false).should_not be_enabled
  end

  it 'does not evaluate its contexts when disabled' do
    expect { described_class.new(enabled:  true).context('c') { raise 'omg' } }.to raise_error 'omg'
    expect { described_class.new(enabled: false).context('c') { raise 'omg' } }.to_not raise_error
  end

  it 'caches results under a name which all appear consecutively next to eachother regardless of when they were called' do
    described_class.new(enabled: true, color: false)
                   .context('a') { '1' }
                   .context('b') { '3' }
                   .context('a') { '2' }
                   .to_s.should == "a:\n1\n2\n\nb:\n3\n"
  end

  specify 'colouring is disabled by default' do
    described_class.new(enabled: true, colour: true).context('AAA') { 'BBB' }.to_s.should ==
      "#{described_class::CONTEXT_COLOUR}AAA:#{described_class::RESET_COLOUR}\nBBB\n"
  end
end
