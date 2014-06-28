require 'ichannel'
require 'seeing_is_believing/hard_core_ensure'

describe SeeingIsBelieving::HardCoreEnsure do
  def call(options)
    described_class.new(options).call
  end

  it "raises an argument error if it doesn't get a code proc" do
    expect { call ensure: -> {} }.to raise_error ArgumentError, "Must pass the :code key"
  end

  it "raises an argument error if it doesn't get an ensure proc" do
    expect { call code: -> {} }.to raise_error ArgumentError, "Must pass the :ensure key"
  end

  it "raises an argument error if it gets any other keys" do
    expect { call code: -> {}, ensure: -> {}, other: 123 }.to \
      raise_error ArgumentError, "Unknown key: :other"

    expect { call code: -> {}, ensure: -> {}, other1: 123, other2: 456 }.to \
      raise_error ArgumentError, "Unknown keys: :other1, :other2"
  end

  it 'invokes the code and returns the value' do
    call(code: -> { :result }, ensure: -> {}).should == :result
  end

  it 'invokes the ensure after the code' do
    seen = []
    call code: -> { seen << :code }, ensure: -> { seen << :ensure }
    seen.should == [:code, :ensure]
  end

  it 'invokes the ensure even if an exception is raised' do
    ensure_invoked = false
    expect do
      call code: -> { raise Exception, 'omg!' }, ensure: -> { ensure_invoked = true }
    end.to raise_error Exception, 'omg!'
    ensure_invoked.should == true
  end

  it 'invokes the code even if an interrupt is sent and there is a default handler' do
    channel = IChannel.new Marshal
    pid = fork do
      old_handler = trap('INT') { channel.put "old handler invoked" }
      call code: -> { sleep 0.1 }, ensure: -> { channel.put "ensure invoked" }
      trap 'INT', old_handler
    end
    sleep 0.05
    Process.kill 'INT', pid
    Process.wait pid
    channel.get.should == "ensure invoked"
    channel.get.should == "old handler invoked"
    channel.should_not be_readable
  end

  it 'invokes the code even if an interrupt is sent and interrupts are set to ignore' do
    test = lambda do
      channel = IChannel.new Marshal
      pid = fork do
        old_handler = trap 'INT', 'IGNORE'
        result = call code: -> { sleep 0.1; 'code result' }, ensure: -> { channel.put "ensure invoked" }
        channel.put result
        trap 'INT', old_handler
      end
      sleep 0.05
      Process.kill 'INT', pid
      Process.wait pid
      channel.get.should == "ensure invoked"
      channel.get.should == 'code result'
      channel.should_not be_readable
    end

    if RUBY_VERSION == '2.1.1' || RUBY_VERSION == '2.1.2'
      pending 'This test can\'t run on 2.1.1 or 2.1.2'
    else
      test.call
    end
  end
end
