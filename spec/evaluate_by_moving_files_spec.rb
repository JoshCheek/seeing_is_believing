# encoding: utf-8

require 'spec_helper'
require 'seeing_is_believing/evaluate_by_moving_files'
require 'fileutils'

RSpec.describe SeeingIsBelieving::EvaluateByMovingFiles do
  let(:filedir)  { File.expand_path '../../proving_grounds', __FILE__ }
  let(:filename) { File.join filedir, 'some_filename' }

  before { FileUtils.mkdir_p filedir }

  def matrix_file
    'seeing_is_believing/the_matrix'
  end

  def null_options(overrides={})
    {event_handler: lambda { |*| }}.merge(overrides)
  end

  def invoke(program, options={})
    result  = SeeingIsBelieving::Result.new
    options = null_options(
      event_handler:  lambda { |event| SeeingIsBelieving::EventStream::UpdateResult.call result, event },
    ).merge(options)
    evaluator = described_class.new(program, filename, options)
    FileUtils.rm_f evaluator.backup_filename
    evaluator.call
    result
  end

  it 'evaluates the code when the file DNE' do
    FileUtils.rm_f filename
    debugger = SeeingIsBelieving::Debugger.new stream: $stdout
    expect(invoke('print 1', debugger: debugger).stdout).to eq '1'
  end

  it 'evaluates the code when the file Exists' do
    FileUtils.touch filename
    expect(invoke('print 1').stdout).to eq '1'
  end

  it 'raises an error when the temp file already exists' do
    evaluator = described_class.new('', filename, null_options)
    FileUtils.touch evaluator.backup_filename
    expect { evaluator.call }.to raise_error SeeingIsBelieving::TempFileAlreadyExists
  end

  it 'evaluates the code as the given file' do
    expect(invoke('print __FILE__').stdout).to eq filename
  end

  it 'does not change the original file' do
    File.open(filename, 'w') { |f| f.write "ORIGINAL" }
    invoke '1 + 1'
    expect(File.read filename).to eq "ORIGINAL"
  end

  it 'uses HardCoreEnsure to move the file back' do
    evaluator = described_class.new 'PROGRAM', filename, null_options
    File.open(filename, 'w') { |f| f.write 'ORIGINAL' }
    FileUtils.rm_rf evaluator.backup_filename
    expect(SeeingIsBelieving::HardCoreEnsure).to receive(:call) do |options|
      # initial state
      expect(File.exist? evaluator.backup_filename).to eq false
      expect(File.read filename).to eq 'ORIGINAL'

      # after code
      options[:code].call rescue nil
      expect(File.read evaluator.backup_filename).to eq 'ORIGINAL'
      expect(File.read filename).to eq 'PROGRAM'

      # after ensure
      options[:ensure].call
      expect(File.read filename).to eq 'ORIGINAL'
      expect(File.exist? evaluator.backup_filename).to eq false
    end
    evaluator.call
  end

  it 'uses HardCoreEnsure to delete the file if it wrote it where one did not previously exist' do
    evaluator = described_class.new 'PROGRAM', filename, null_options
    FileUtils.rm_rf filename
    expect(SeeingIsBelieving::HardCoreEnsure).to receive(:call) do |options|
      # initial state
      expect(File.exist? filename).to eq false

      # after code
      options[:code].call rescue nil
      expect(File.read filename).to eq 'PROGRAM'

      # after ensure
      options[:ensure].call
      expect(File.exist? filename).to eq false
    end
    evaluator.call
  end

  it 'can require files' do
    other_filename1 = File.join filedir, 'other1.rb'
    other_filename2 = File.join filedir, 'other2.rb'
    File.open(other_filename1, 'w') { |f| f.puts "puts 123" }
    File.open(other_filename2, 'w') { |f| f.puts "puts 456" }
    result = invoke '', require: [matrix_file, other_filename1, other_filename2]
    expect(result.stdout).to eq "123\n456\n"
  end

  it 'can set the load path' do
    File.open(File.join(filedir, 'other1.rb'), 'w') { |f| f.puts "puts 123" }
    result = invoke '', require: [matrix_file, 'other1'], load_path: [filedir]
    expect(result.stdout).to eq "123\n"
  end

  it 'can set the encoding' do
    test = -> { expect(invoke('print "ç"', encoding: 'u').stdout).to eq "ç" }
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
      pending "Rubinius doesn't seem to use -Kx, but rather -U"
      test.call
    else
      test.call
    end
  end

  it 'does not blow up on exceptions raised in at_exit blocks' do
    expect { invoke 'at_exit { raise "zomg" }' }.to_not raise_error
  end

  it 'can provide stdin as a string or stream' do
    expect(invoke('p gets', provided_input: 'a').stdout).to eq %("a"\n)
    require 'stringio'
    result = invoke 'p gets', provided_input: StringIO.new('b')
    expect(result.stdout).to eq %("b"\n)
  end

  it 'can set a timeout' do
    expect(Timeout).to receive(:timeout).with(123).and_raise(Timeout::Error)
    expect(Process).to receive(:kill)
    expect { expect(invoke('p gets', timeout_seconds: 123).stdout).to eq %("a"\n) }
      .to raise_error Timeout::Error
  end

  it 'raises an ArgumentError if given arguments it doesn\'t know' do
    expect { invoke '1', watisthis: :idontknow }
      .to raise_error ArgumentError, /watisthis/
  end
end
