# encoding: utf-8

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
    invoke('print 1').stdout.should == '1'
  end

  it 'evaluates the code when the file Exists' do
    FileUtils.touch filename
    invoke('print 1').stdout.should == '1'
  end

  it 'raises an error when the temp file already exists' do
    evaluator = described_class.new('', filename)
    FileUtils.touch evaluator.temp_filename
    expect { evaluator.call }.to raise_error SeeingIsBelieving::TempFileAlreadyExists
  end

  it 'evaluates the code as the given file' do
    invoke('print __FILE__').stdout.should == filename
  end

  it 'does not change the original file' do
    File.open(filename, 'w') { |f| f.write "ORIGINAL" }
    invoke '1 + 1'
    File.read(filename).should == "ORIGINAL"
  end

  it 'uses HardCoreEnsure to move the file back' do
    evaluator = described_class.new 'PROGRAM', filename
    File.open(filename, 'w') { |f| f.write 'ORIGINAL' }
    FileUtils.rm_rf evaluator.temp_filename
    expect(SeeingIsBelieving::HardCoreEnsure).to receive(:call) do |options|
      # initial state
      File.exist?(evaluator.temp_filename).should == false
      File.read(filename).should == 'ORIGINAL'

      # after code
      options[:code].call rescue nil
      File.read(evaluator.temp_filename).should == 'ORIGINAL'
      File.read(filename).should == 'PROGRAM'

      # after ensure
      options[:ensure].call
      File.read(filename).should == 'ORIGINAL'
      File.exist?(evaluator.temp_filename).should == false
    end
    evaluator.call
  end

  it 'uses HardCoreEnsure to delete the file if it wrote it where one did not previously exist' do
    evaluator = described_class.new 'PROGRAM', filename
    FileUtils.rm_rf filename
    expect(SeeingIsBelieving::HardCoreEnsure).to receive(:call) do |options|
      # initial state
      File.exist?(filename).should == false

      # after code
      options[:code].call rescue nil
      File.read(filename).should == 'PROGRAM'

      # after ensure
      options[:ensure].call
      File.exist?(filename).should == false
    end
    evaluator.call
  end

  it 'can require files' do
    other_filename1 = File.join filedir, 'other1.rb'
    other_filename2 = File.join filedir, 'other2.rb'
    File.open(other_filename1, 'w') { |f| f.puts "puts 123" }
    File.open(other_filename2, 'w') { |f| f.puts "puts 456" }
    result = invoke '', require: [other_filename1, other_filename2]
    result.stdout.should == "123\n456\n"
  end

  it 'can set the load path' do
    File.open(File.join(filedir, 'other1.rb'), 'w') { |f| f.puts "puts 123" }
    result = invoke '', require: ['other1'], load_path: [filedir]
    result.stdout.should == "123\n"
  end

  it 'will set the encoding' do
    test = -> { invoke('print "ç"', encoding: 'u').stdout.should == "ç" }
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
    error_stream.string.should include "Program could not be evaluated"
  end
end
