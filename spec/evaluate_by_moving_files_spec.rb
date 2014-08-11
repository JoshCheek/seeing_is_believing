# encoding: utf-8

require 'spec_helper'
require 'seeing_is_believing/evaluate_by_moving_files'
require 'fileutils'

describe SeeingIsBelieving::EvaluateByMovingFiles do
  let(:filedir)  { File.expand_path '../../proving_grounds', __FILE__ }
  let(:filename) { File.join filedir, 'some_filename' }

  before { FileUtils.mkdir_p filedir }

  def invoke(program, options={})
    evaluator = described_class.new(program, filename, options)
    FileUtils.rm_f evaluator.temp_filename
    evaluator.call
  end

  it 'evaluates the code when the file DNE' do
    FileUtils.rm_f filename
    expect(invoke('print 1').stdout).to eq '1'
  end

  it 'evaluates the code when the file Exists' do
    FileUtils.touch filename
    expect(invoke('print 1').stdout).to eq '1'
  end

  it 'raises an error when the temp file already exists' do
    evaluator = described_class.new('', filename)
    FileUtils.touch evaluator.temp_filename
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
    evaluator = described_class.new 'PROGRAM', filename
    File.open(filename, 'w') { |f| f.write 'ORIGINAL' }
    FileUtils.rm_rf evaluator.temp_filename
    expect(SeeingIsBelieving::HardCoreEnsure).to receive(:call) do |options|
      # initial state
      expect(File.exist? evaluator.temp_filename).to eq false
      expect(File.read filename).to eq 'ORIGINAL'

      # after code
      options[:code].call rescue nil
      expect(File.read evaluator.temp_filename).to eq 'ORIGINAL'
      expect(File.read filename).to eq 'PROGRAM'

      # after ensure
      options[:ensure].call
      expect(File.read filename).to eq 'ORIGINAL'
      expect(File.exist? evaluator.temp_filename).to eq false
    end
    evaluator.call
  end

  it 'uses HardCoreEnsure to delete the file if it wrote it where one did not previously exist' do
    evaluator = described_class.new 'PROGRAM', filename
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
    result = invoke '', require: [other_filename1, other_filename2]
    expect(result.stdout).to eq "123\n456\n"
  end

  it 'can set the load path' do
    File.open(File.join(filedir, 'other1.rb'), 'w') { |f| f.puts "puts 123" }
    result = invoke '', require: ['other1'], load_path: [filedir]
    expect(result.stdout).to eq "123\n"
  end

  it 'will set the encoding' do
    test = -> { expect(invoke('print "ç"', encoding: 'u').stdout).to eq "ç" }
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
      pending "Rubinius doesn't seem to use -Kx, but rather -U" do
        test.call
      end
    else
      test.call
    end
  end

  it 'if it fails, it prints some debugging information and raises an error' do
    error_stream = StringIO.new
    evaluator = described_class.new 'raise "omg"', filename, debugger: SeeingIsBelieving::Debugger.new(stream: error_stream)
    FileUtils.rm_f evaluator.temp_filename
    expect { evaluator.call }.to raise_error SeeingIsBelieving::BugInSib
    expect(error_stream.string).to include "Program could not be evaluated"
  end
end
