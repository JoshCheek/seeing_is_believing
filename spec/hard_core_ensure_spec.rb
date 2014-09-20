require 'spec_helper'
require 'ichannel'
require 'seeing_is_believing/hard_core_ensure'

RSpec.describe SeeingIsBelieving::HardCoreEnsure do
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
    expect(call(code: -> { :result }, ensure: -> {})).to eq :result
  end

  it 'invokes the ensure after the code' do
    seen = []
    call code: -> { seen << :code }, ensure: -> { seen << :ensure }
    expect(seen).to eq [:code, :ensure]
  end

  it 'invokes the ensure even if an exception is raised' do
    ensure_invoked = false
    expect do
      call code: -> { raise Exception, 'omg!' }, ensure: -> { ensure_invoked = true }
    end.to raise_error Exception, 'omg!'
    expect(ensure_invoked).to eq true
  end

  it 'invokes the code even if an interrupt is sent and there is a default handler' do
    test = lambda do
      channel = IChannel.new Marshal
      pid = fork do
        old_handler = trap('INT') { channel.put "old handler invoked" }
        call code: -> { sleep 0.1 }, ensure: -> { channel.put "ensure invoked" }
        trap 'INT', old_handler
      end
      sleep 0.05
      Process.kill 'INT', pid
      Process.wait pid
      expect(channel.get).to eq "ensure invoked"
      expect(channel.get).to eq "old handler invoked"
      expect(channel).to_not be_readable
    end
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      pending "Skipping this test on jruby b/c the JVM doesn't have a fork"
      raise
    else
      test.call
    end
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
      expect(channel.get).to eq "ensure invoked"
      expect(channel.get).to eq 'code result'
      expect(channel).to_not be_readable
    end

    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      pending "Skipping this test on jruby b/c the JVM doesn't have a fork"
      raise # new rspec will keep executing code and fail b/c nothing is raised
    elsif (!defined?(RUBY_ENGINE) || RUBY_ENGINE == 'ruby') && (RUBY_VERSION == '2.1.1' || RUBY_VERSION == '2.1.2')
      pending 'This test can\'t run on MRI (2.1.1 or 2.1.2) b/c of bug, see https://github.com/JoshCheek/seeing_is_believing/issues/26'
      raise # new rspec will keep executing code and fail b/c nothing is raised
    else
      test.call # works on Rubinius
    end
  end
end
