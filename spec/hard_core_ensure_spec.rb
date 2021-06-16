require 'spec_helper'
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

  def ruby(program)
    child = ChildProcess.build RbConfig.ruby,
                               '-I', File.expand_path('../lib', __dir__),
                               '-r', 'seeing_is_believing/hard_core_ensure',
                               '-e', program
    child.duplex = true
    outread, outwrite = IO.pipe
    errread, errwrite = IO.pipe
    child.io.stdout = outwrite
    child.io.stderr = errwrite
    child.start
    outwrite.close
    errwrite.close
    yield child, outread
  ensure
    errread && !errread.closed? && expect(errread.read).to(be_empty)
    outread.close unless outread.closed?
  end


  # for fuck sake, I can't get Windows to let me trap the interrupt
  it 'invokes the code even if an interrupt is sent and there is a default handler', windows: false do
    program = <<-RUBY
      trap("INT") do
        puts %(CUSTOM-HANDLER)
        exit
      end
      SeeingIsBelieving::HardCoreEnsure.new(
        code:   -> { puts %(CODE); $stdout.flush; sleep },
        ensure: -> { puts %(ENSURE) },
      ).call
    RUBY
    ruby program do |ps, psout|
      expect(psout.gets.chomp).to eq "CODE"
      # is_alive = ChildProcess::Windows::Lib.alive?(ps.pid)
      Process.kill 'INT', ps.pid

      expect(psout.gets.chomp).to eq "ENSURE"
      expect(psout.gets.chomp).to eq "CUSTOM-HANDLER"
    end
  end

  it 'invokes the code even if an interrupt is sent and interrupts are set to ignore', windows: false do
    # empty string isn't documented, but it causes ignore too
    # https://github.com/ruby/ruby/blob/256d8c9ecffbcd8f4fe7562b866fcd55f1d445e7/signal.c#L1128-L1129
    ignore_handlers = ['IGNORE', 'SIG_IGN', '']

    ignore_handlers.each do |handler|
      program = <<-RUBY
        trap %(INT), #{handler.inspect}
        SeeingIsBelieving::HardCoreEnsure.new(
          code:   -> {
            puts %(CODE1)
            $stdout.flush
            gets
            puts %(CODE2)
          },
          ensure: -> { puts %(ENSURE) },
        ).call
      RUBY
      ruby program do |ps, psout|
        expect(psout.gets).to eq "CODE1\n" # we're in the code block
        Process.kill 'INT', ps.pid         # should be ignored

        # note that if we don't check this, the pipe on the next line may beat the signal
        # to the process leading to nondeterministic printing
        expect(ps).to be_alive

        ps.io.stdin.puts "wake up!"
        ps.wait
        expect(ps.exit_code).to eq 0
        expect(psout.gets).to eq "CODE2\n"
        expect(psout.gets).to eq "ENSURE\n"
        expect(psout.gets).to eq nil
      end
    end
  end
end
