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
    evaluator = described_class.new 'PROGRAM', filename, error_stream: StringIO.new
    File.open(filename, 'w') { |f| f.write 'ORIGINAL' }
    FileUtils.rm_rf evaluator.temp_filename
    SeeingIsBelieving::HardCoreEnsure.should_receive(:call) do |options|
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

  it 'prints some error handling code to stderr if it fails' do
    stderr    = StringIO.new
    evaluator = described_class.new 'raise "omg"', filename, error_stream: stderr
    FileUtils.rm_f evaluator.temp_filename
    expect { evaluator.call }.to raise_error
    stderr.string.should include "It blew up"
  end
end
