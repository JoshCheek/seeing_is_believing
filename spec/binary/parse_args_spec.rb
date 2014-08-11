require 'spec_helper'
require 'seeing_is_believing/binary/parse_args'

describe SeeingIsBelieving::Binary::ParseArgs do
  RSpec::Matchers.define :have_error do |error_assertion|
    match do |options|
      options[:errors].find do |error|
        case error_assertion
        when Regexp
          error_assertion =~ error
        else
          error_assertion == error
        end
      end
    end

    failure_message do |options|
      "#{error_assertion.inspect} should have matched one of the errors: #{options[:errors].inspect}"
    end

    failure_message_when_negated do |options|
      "#{error_assertion.inspect} should NOT have matched any of the errors: #{options[:errors].inspect}"
    end
  end

  def parse(args, outstream=nil)
    SeeingIsBelieving::Binary::ParseArgs.call args, outstream
  end

  shared_examples 'it requires a positive int argument' do |flags|
    it 'expects an integer argument' do
      flags.each do |flag|
        expect(parse([flag,   '1'])).to_not have_error /#{flag}/
        expect(parse([flag,   '0'])).to     have_error /#{flag}/
        expect(parse([flag,  '-1'])).to     have_error /#{flag}/
        expect(parse([flag, '1.0'])).to     have_error /#{flag}/
        expect(parse([flag,   'a'])).to     have_error /#{flag}/
        expect(parse([flag,   '' ])).to     have_error /#{flag}/
        expect(parse([flag       ])).to     have_error /#{flag}/
      end
    end
  end

  shared_examples 'it requires a non-negative float or int' do |flags|
    it 'expects a non-negative float or int argument' do
      flags.each do |flag|
        expect(parse([flag,   '1'])).to_not have_error /#{flag}/
        expect(parse([flag,   '0'])).to_not have_error /#{flag}/
        expect(parse([flag,  '-1'])).to     have_error /#{flag}/
        expect(parse([flag,'-1.0'])).to     have_error /#{flag}/
        expect(parse([flag, '1.0'])).to_not have_error /#{flag}/
        expect(parse([flag,   'a'])).to     have_error /#{flag}/
        expect(parse([flag,   '' ])).to     have_error /#{flag}/
        expect(parse([flag       ])).to     have_error /#{flag}/
      end
    end
  end

  specify 'unknown options set an error' do
    expect(parse(['--xyz'])).to have_error 'Unknown option: "--xyz"'
    expect(parse(['-y'])).to have_error 'Unknown option: "-y"'
    expect(parse(['-y', 'b'])).to have_error 'Unknown option: "-y"'
  end

  example 'example: multiple args' do
    options = parse(%w[filename -l 12 -L 20 -h -r torequire])
    expect(options[:filename]).to eq 'filename'
    expect(options[:start_line]).to eq 12
    expect(options[:end_line]).to eq 20
    expect(options[:require]).to eq ['torequire']
    expect(options[:help]).to be_a_kind_of String
    expect(options[:errors]).to be_empty
  end

  describe ':filename' do
    it 'defaults to nil' do
      expect(parse([])[:filename]).to be_nil
    end

    it 'is the first non-flag' do
      expect(parse(['a'])[:filename]).to eq 'a'
      expect(parse(['-x', 'a'])[:filename]).to eq 'a'
      expect(parse(['a', '-x'])[:filename]).to eq 'a'
    end

    it 'sets an error if given multiple filenames' do
      expect(parse([])).to_not have_error /name/
      expect(parse(['a'])).to_not have_error /Can only have one filename/
      expect(parse(['a', 'b'])).to have_error 'Can only have one filename, but had: "a", "b"'
    end
  end

  describe ':start_line' do
    it 'defaults to 1' do
      expect(parse([])[:start_line]).to equal 1
    end

    it 'is set with -l and --start-line' do
      expect(parse(['-l', '1'])[:start_line]).to eq 1
      expect(parse(['--start-line', '12'])[:start_line]).to eq 12
    end

    it_behaves_like 'it requires a positive int argument', ['-l', '--start-line']
  end

  describe ':end_line' do
    it 'defaults to infinity' do
      expect(parse([])[:end_line]).to equal Float::INFINITY
    end

    it 'is set with -L and --end-line' do
      expect(parse(['-L', '1'])[:end_line]).to eq 1
      expect(parse(['--end-line', '12'])[:end_line]).to eq 12
    end

    it_behaves_like 'it requires a positive int argument', ['-L', '--end-line']
  end

  it 'swaps start and end line around if they are out of order' do
    expect(parse(%w[-l 2 -L 1])[:start_line]).to eq 1
    expect(parse(%w[-l 2 -L 1])[:end_line]).to eq 2
  end

  describe ':result_length' do
    it 'defaults to infinity' do
      expect(parse([])[:max_result_length]).to eq Float::INFINITY
    end

    it 'is set with -D and --result-length' do
      expect(parse(['-D',              '10'])[:max_result_length]).to eq 10
      expect(parse(['--result-length', '10'])[:max_result_length]).to eq 10
    end

    it_behaves_like 'it requires a positive int argument', ['-D', '--result-length']
  end

  describe ':max_line_length' do
    it 'defaults to infinity' do
      expect(parse([])[:max_line_length]).to eq Float::INFINITY
    end

    it 'is set with -d and --line-length' do
      expect(parse(['-d',            '10'])[:max_line_length]).to eq 10
      expect(parse(['--line-length', '10'])[:max_line_length]).to eq 10
    end

    it_behaves_like 'it requires a positive int argument', ['-d', '--line-length']
  end

  describe :require do
    it 'defaults to an empty array' do
      expect(parse([])[:require]).to be_empty
    end

    it '-r and --require sets each required file into the result array' do
      expect(parse(%w[-r f1 --require f2])[:require]).to eq %w[f1 f2]
    end

    it 'sets an error if not provided with a filename' do
      expect(parse(['--require', 'f'])).to_not have_error /-r/
      expect(parse(['-r'])).to have_error /-r\b/
      expect(parse(['--require'])).to have_error /--require\b/
    end
  end

  describe ':help' do
    it 'defaults to nil' do
      expect(parse([])[:help]).to be_nil
    end

    it 'is set to the flag only help screen with -h and --help and -help' do
      expect(parse(['-h'])[:help]).to include 'Usage:'
      expect(parse(['--help'])[:help]).to include 'Usage:'

      expect(parse(['-h'])[:help]).to_not include 'Examples:'
      expect(parse(['--help'])[:help]).to_not include 'Examples:'
    end

    it 'is set to the flag with examples help screen with --help+ and -h+' do
      expect(parse(['-h+'])[:help]).to include 'Usage:'
      expect(parse(['--help+'])[:help]).to include 'Usage:'

      expect(parse(['-h+'])[:help]).to include 'Examples:'
      expect(parse(['--help+'])[:help]).to include 'Examples:'
    end
  end

  describe ':program' do
    it 'defaults to nil' do
      expect(parse([])[:program]).to be_nil
    end

    it 'is set with -e or --program, and takes the next arg' do
      expect(parse(['-e', '1'])[:program]).to eq '1'
      expect(parse(['--program', '1'])[:program]).to eq '1'
    end

    it 'sets an error if not given a program' do
      expect(parse([])).to_not have_error /-e/
      expect(parse([])).to_not have_error /--program/
      expect(parse(['-e'])).to have_error /-e/
      expect(parse(['--program'])).to have_error /--program/
    end

    it 'sets an error if a filename is also give' do
      expect(parse(['-e', '1'])).to_not have_error /-e/
      expect(parse(['-e', '1', 'abc'])).to have_error /"abc"/
    end
  end

  describe':load_path' do
    it 'defaults to an empty array' do
      expect(parse([])[:load_path]).to be_empty
    end

    specify '-I and --load-path sets each required file into the result array' do
      expect(parse(%w[-I f1 --load-path f2])[:load_path]).to eq %w[f1 f2]
    end

    it 'sets an error if not provided with a dir' do
      expect(parse(['--load-path', 'f'])).to_not have_error /-I/
      expect(parse(['-I'])).to have_error /-I\b/
      expect(parse(['--load-path'])).to have_error /--load-path\b/
    end
  end

  describe ':encoding' do
    it 'defaults to nil' do
      expect(parse([])[:encoding]).to be_nil
    end

    specify '-K and --encoding sets the encoding to the next argument' do
      expect(parse(%w[-K u])[:encoding]).to eq 'u'
      expect(parse(%w[--encoding u])[:encoding]).to eq 'u'
    end

    specify 'with -K, the argument can be placed immediately after it (e.g. -Ku) because Ruby allows this' do
      expect(parse(['-Ku'])[:encoding]).to eq 'u'
      expect(parse(['-Ku'])).to_not have_error /-K/
    end

    it 'sets an error if not provided with an encoding' do
      expect(parse(['-Ku'])).to_not have_error /-K/
      expect(parse(['-K u'])).to_not have_error /-K/
      expect(parse(['--encoding', 'u'])).to_not have_error /--encoding/
      expect(parse(['-K'])).to have_error /-K/
      expect(parse(['--encoding'])).to have_error /--encoding/
    end
  end

  describe ':as' do
    it 'defaults to nil' do
      expect(parse([])[:as]).to be_nil
    end

    it 'can be set with -a and --as' do
      expect(parse(%w[-a   abc])[:as]).to eq 'abc'
      expect(parse(%w[--as abc])[:as]).to eq 'abc'
    end

    it 'sets an error if not provided with a filename' do
      expect(parse(%w[-a  f])).to_not have_error /-a/
      expect(parse(%w[-as f])).to_not have_error /--as/
      expect(parse(%w[-a   ])).to have_error /-a/
      expect(parse(%w[--as ])).to have_error /--as/
    end
  end

  describe ':clean' do
    it 'defaults to false' do
      expect(parse([])[:clean]).to eq false
    end

    it 'can be set with -c and --clean' do
      expect(parse(%w[-c])[:clean]).to eq true
      expect(parse(%w[--clean])[:clean]).to eq true
    end
  end

  describe ':version' do
    it 'defaults to false' do
      expect(parse([])[:version]).to eq false
    end

    it 'can be set with -v and --version' do
      expect(parse(%w[-v])[:version]).to eq true
      expect(parse(%w[--version])[:version]).to eq true
    end
  end

  describe ':timeout' do
    it 'defaults to 0' do
      expect(parse([])[:timeout]).to eq 0
    end

    it_behaves_like 'it requires a non-negative float or int', ['-t', '--timeout']
  end

  describe ':alignment_strategy' do
    AlignFile  = SeeingIsBelieving::Binary::AlignFile
    AlignLine  = SeeingIsBelieving::Binary::AlignLine
    AlignChunk = SeeingIsBelieving::Binary::AlignChunk

    # maybe change the default?
    it 'defaults to AlignChunk' do
      expect(parse([])[:alignment_strategy]).to eq AlignChunk
    end

    specify '-s and --alignment-strategy sets the alignment strategy' do
      expect(parse(['-s',                   'chunk'])[:alignment_strategy]).to eq AlignChunk
      expect(parse(['--alignment-strategy', 'chunk'])[:alignment_strategy]).to eq AlignChunk
    end

    it 'accepts values: file, line, chunk' do
      expect(parse(['-s',  'file'])[:alignment_strategy]).to eq AlignFile
      expect(parse(['-s',  'line'])[:alignment_strategy]).to eq AlignLine
      expect(parse(['-s', 'chunk'])[:alignment_strategy]).to eq AlignChunk
    end

    it 'sets an error if not provided with a strategy, or if provided with an unknown strategy' do
      expect(parse(['-s', 'file'])).to_not have_error /alignment-strategy/
      expect(parse(['-s',  'abc'])).to     have_error /alignment-strategy/
      expect(parse(['-s'        ])).to     have_error /alignment-strategy/
    end
  end

  describe ':inherit_exit_status' do
    it 'defaults to false' do
      expect(parse([])[:inherit_exit_status]).to eq false
    end

    it 'can be set with --inherit-exit-status or -i' do
      expect(parse(['--inherit-exit-status'])[:inherit_exit_status]).to be true
      expect(parse(['-i'])[:inherit_exit_status]).to be true
    end
  end

  describe ':xmpfilter_style' do
    it 'defaults to false' do
      expect(parse([])[:xmpfilter_style]).to be false
    end

    it 'can be set with --xmpfilter-style or -x' do
      expect(parse(['--xmpfilter-style'])[:xmpfilter_style]).to be true
      expect(parse(['-x'])[:xmpfilter_style]).to be true
    end
  end

  describe ':debugger' do
    it 'defaults to a debugger that is disabled' do
      expect(parse([], :fake_stream)[:debugger]).to_not be_enabled
    end

    it 'can be enabled with --debug or -g' do
      expect(parse(['--debug'], :fake_stream)[:debugger]).to be_enabled
      expect(parse(['-g'], :fake_stream)[:debugger]).to be_enabled
    end

    it 'sets the stream to the one passed in' do
      expect(parse(['-g'], :fake_stream)[:debugger].stream).to eq :fake_stream
    end
  end

  describe ':shebang' do
    it 'defaults to "ruby"' do
      expect(parse([])[:shebang]).to eq 'ruby'
    end

    it 'can be enabled with --shebang' do
      expect(parse(['--shebang', 'not_ruby'])[:shebang]).to eq 'not_ruby'
    end

    it 'sets an error if not given a next arg to execute' do
      expect(parse([])).to_not have_error /--shebang/
      expect(parse(['--shebang'])).to have_error /--shebang/
    end
  end

  describe ':number_of_captures' do
    it 'defaults to infinity' do
      expect(parse([])[:number_of_captures]).to eq Float::INFINITY
    end

    it 'can be set with --number-of-captures or -n' do
      expect(parse(['-n', '10'])[:number_of_captures]).to eq 10
      expect(parse(['--number-of-captures', '10'])[:number_of_captures]).to eq 10
    end

    it_behaves_like 'it requires a positive int argument', ['-n', '--number-of-captures']
  end

  describe ':result_as_json' do
    it 'defaults to false' do
      expect(parse([])[:result_as_json]).to eq false
    end

    it 'can be enabled with --json or -j' do
      expect(parse(['--json'])[:result_as_json]).to eq true
      expect(parse(['-j'])[:result_as_json]).to eq true
    end
  end
end

