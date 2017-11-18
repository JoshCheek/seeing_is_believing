# encoding: utf-8

require 'spec_helper'
require 'seeing_is_believing/evaluate_by_moving_files'
require 'seeing_is_believing/event_stream/handlers/update_result'
require 'fileutils'
require 'childprocess'

RSpec.describe SeeingIsBelieving::EvaluateByMovingFiles do
  let(:filedir)  { File.expand_path '../proving_grounds', __dir__ }
  let(:filename) { File.join filedir, 'some_filename' }

  before { FileUtils.mkdir_p filedir }

  def matrix_file
    'seeing_is_believing/the_matrix'
  end

  def null_options(overrides={})
    { event_handler: lambda { |*| } }
  end

  def invoke(program, options={})
    result = SeeingIsBelieving::Result.new
    options[:event_handler] ||= SeeingIsBelieving::EventStream::Handlers::UpdateResult.new(result)
    evaluator = described_class.new(program, filename, options)
    FileUtils.rm_f evaluator.backup_filename
    evaluator.call
    result
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
    result = invoke '', require_files: [matrix_file, other_filename1, other_filename2]
    expect(result.stdout).to eq "123\n456\n"
  end

  it 'can set the load path' do
    File.open(File.join(filedir, 'other1.rb'), 'w') { |f| f.puts "puts 123" }
    result = invoke '', require_files: [matrix_file, 'other1'], load_path_dirs: [filedir]
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

  it 'sets the program\'s working directory to the file\'s directory, when given local_cwd' do
    Dir.chdir '/' do
      root   = File.expand_path '/'
      result = invoke 'print Dir.pwd'
      expect(result.stdout).to eq root
      dir, cwd, file_path = invoke(<<-RUBY, local_cwd: true).stdout.lines.map(&:chomp)
        puts File.expand_path(__dir__)
        puts Dir.pwd
        puts __FILE__
      RUBY
      expect(dir).to_not eq root
      expect(cwd).to eq dir
      expect(file_path).to eq File.basename(filename)
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

  it 'must provide an event handler, which receives the process\'s events' do
    # raises error
    expect { described_class.new("", filename, {}) }
      .to raise_error ArgumentError, /event_handler/

    # sees all the events
    seen = []
    invoke '1', event_handler: lambda { |e| seen << e }
    expect(seen).to_not be_empty
    expect(seen.last).to eq SeeingIsBelieving::EventStream::Events::Finished.new
  end

  it 'can set a timeout, which interrupts the process group and then waits for the events to finish' do
    pre    = Time.now
    result = invoke <<-RUBY, timeout_seconds: 0.5
    child_pid = spawn 'ruby', '-e', 'sleep' # child makes a grandchild which sleeps
    puts Process.pid, child_pid             # print ids so we can check they got killed
    sleep                                   # child sleeps
    RUBY
    post   = Time.now
    expect(result.timeout?).to eq true
    expect(result.timeout_seconds).to eq 0.5
    expect(post - pre).to be > 0.5
    child_id, grandchild_id, *rest = result.stdout.lines
    expect(child_id).to match /^\d+$/
    expect(grandchild_id).to match /^\d+$/
    expect(rest).to be_empty
    expect { Process.wait child_id.to_i      } .to raise_error /no.*processes/i
    expect { Process.wait grandchild_id.to_i } .to raise_error /no.*processes/i
  end

  it 'raises an ArgumentError if given arguments it doesn\'t know' do
    expect { invoke '1', watisthis: :idontknow }
      .to raise_error ArgumentError, /watisthis/
  end

  it 'doesn\'t explode or do anything else obnoxious when the input stream is closed' do
    infinite_string = Object.new
    def infinite_string.each_char
      loop { yield 'c' }
    end
    result = nil
    expect {
      result = invoke '$stdin.close', provided_input: infinite_string
    }.to_not output.to_stderr
    expect(result.exitstatus).to eq 0
    expect(result.stderr).to be_empty
    expect(result.stdout).to be_empty
  end
end
