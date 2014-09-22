require 'spec_helper'
require 'seeing_is_believing/binary/parse_args'

RSpec.describe SeeingIsBelieving::Binary::ParseArgs do
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

  def parse(args)
    SeeingIsBelieving::Binary::ParseArgs.call args
  end

  def matrix_file
    'seeing_is_believing/the_matrix'
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
    options = parse(%w[filename -h -r torequire])
    expect(options[:filename]).to eq 'filename'
    expect(options[:require]).to include 'torequire'
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

    it 'records all filenames it sees' do
      expect(parse([])[:filenames]).to eq []
      expect(parse(['a'])[:filenames]).to eq ['a']
      expect(parse(['a', 'b'])[:filenames]).to eq ['a', 'b']
    end
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
    it 'defaults to the matrix file array' do
      expect(parse([])[:require]).to eq [matrix_file]
    end

    it '-r and --require sets each required file into the result array' do
      expect(parse(%w[-r f1 --require f2])[:require]).to eq [matrix_file, 'f1', 'f2']
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

    it 'is set to "help" with -h and --help and -help' do
      expect(parse(['-h'])[:help]).to eq 'help'
      expect(parse(['--help'])[:help]).to eq 'help'
    end

    it 'is set to "help+" with examples help screen with --help+ and -h+' do
      expect(parse(['-h+'])[:help]).to eq 'help+'
      expect(parse(['--help+'])[:help]).to eq 'help+'
    end
  end

  describe 'short and long help_screen' do
    specify 'they are the short and long help screens' do
      short = parse([])[:short_help_screen]
      long  = parse([])[:long_help_screen]
      expect(short.length).to be < long.length
      expect(short).to     include 'Usage'
      expect(long).to      include 'Usage'
      expect(short).to_not include 'Examples'
      expect(long).to      include 'Examples'
    end
  end

  describe ':program_from_args' do
    it 'defaults to nil' do
      expect(parse([])[:program_from_args]).to be_nil
    end

    it 'is set with -e or --program, and takes the next arg' do
      expect(parse(['-e', '1'])[:program_from_args]).to eq '1'
      expect(parse(['--program', '1'])[:program_from_args]).to eq '1'
    end

    it 'sets an error if not given a program' do
      expect(parse([])).to_not have_error /-e/
      expect(parse([])).to_not have_error /--program/
      expect(parse(['-e'])).to have_error /-e/
      expect(parse(['--program'])).to have_error /--program/
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
    # TODO: maybe change the default?
    it 'defaults to "chunk"' do
      expect(parse([])[:alignment_strategy]).to eq 'chunk'
    end

    specify '-s and --alignment-strategy sets the alignment strategy' do
      expect(parse(['-s',                   'chunk'])[:alignment_strategy]).to eq 'chunk'
      expect(parse(['--alignment-strategy', 'chunk'])[:alignment_strategy]).to eq 'chunk'
    end

    it 'accepts values: file, line, chunk' do
      expect(parse(['-s',  'file'])[:alignment_strategy]).to eq 'file'
      expect(parse(['-s',  'line'])[:alignment_strategy]).to eq 'line'
      expect(parse(['-s', 'chunk'])[:alignment_strategy]).to eq 'chunk'
    end

    it 'sets an error if not provided with a strategy' do
      expect(parse(['-s', 'file'])).to_not have_error /alignment-strategy/
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

  describe ':debug' do
    it 'defaults to a false' do
      expect(parse([])[:debug]).to eq false
    end

    it 'can be enabled with --debug or -g' do
      expect(parse(['--debug'])[:debug]).to eq true
      expect(parse(['-g'])[:debug]).to eq true
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

  describe ':markers' do
    it 'defaults to a hash with :value, :exception, :stdout, :stderr, and :nextline' do
      expect(parse([])[:markers].keys).to eq [:value, :exception, :stdout, :stderr, :nextline]
    end

    def assert_default(marker_name, value)
      expect(parse([])[:markers][marker_name]).to eq value
    end

    it('defaults :value     to "# => "') { assert_default :value     , "# => " }
    it('defaults :exception to "# ~> "') { assert_default :exception , "# ~> " }
    it('defaults :stdout    to "# >> "') { assert_default :stdout    , "# >> " }
    it('defaults :stderr    to "# !> "') { assert_default :stderr    , "# !> " }
    it('defaults :nextline  to "#    "') { assert_default :nextline  , "#    " }

    # TODO: When things get a little more stable, don't feel like adding all the cukes to play with this right now
    it 'overrides :value     with --value-marker'
    it 'overrides :exception with --exception-marker'
    it 'overrides :stdout    with --stdout-marker'
    it 'overrides :stderr    with --stderr-marker'
    it 'overrides :nextline  with --xmpfilter-nextline-marker'
  end
end

