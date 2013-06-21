require 'seeing_is_believing/binary/arg_parser'

describe SeeingIsBelieving::Binary::ArgParser do
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

    failure_message_for_should do |options|
      "#{error_assertion.inspect} should have matched one of the errors: #{options[:errors].inspect}"
    end

    failure_message_for_should_not do |options|
      "#{error_assertion.inspect} should NOT have matched any of the errors: #{options[:errors].inspect}"
    end
  end

  def parse(args)
    described_class.parse args
  end

  shared_examples 'it requires a positive int argument' do |flags|
    it 'expects an integer argument' do
      flags.each do |flag|
        parse([flag,   '1']).should_not have_error /#{flag}/
        parse([flag,   '0']).should     have_error /#{flag}/
        parse([flag,  '-1']).should     have_error /#{flag}/
        parse([flag, '1.0']).should     have_error /#{flag}/
        parse([flag,   'a']).should     have_error /#{flag}/
        parse([flag,   '' ]).should     have_error /#{flag}/
        parse([flag       ]).should     have_error /#{flag}/
      end
    end
  end

  shared_examples 'it requires a non-negative float or int' do |flags|
    it 'expects a non-negative float or int argument' do
      flags.each do |flag|
        parse([flag,   '1']).should_not have_error /#{flag}/
        parse([flag,   '0']).should_not have_error /#{flag}/
        parse([flag,  '-1']).should     have_error /#{flag}/
        parse([flag,'-1.0']).should     have_error /#{flag}/
        parse([flag, '1.0']).should_not have_error /#{flag}/
        parse([flag,   'a']).should     have_error /#{flag}/
        parse([flag,   '' ]).should     have_error /#{flag}/
        parse([flag       ]).should     have_error /#{flag}/
      end
    end
  end

  specify 'unknown options set an error' do
    parse(['--xyz']).should have_error 'Unknown option: "--xyz"'
    parse(['-x']).should have_error 'Unknown option: "-x"'
    parse(['-x', 'b']).should have_error 'Unknown option: "-x"'
  end

  example 'example: multiple args' do
    options = parse(%w[filename -l 12 -L 20 -h -r torequire])
    options[:filename].should == 'filename'
    options[:start_line].should == 12
    options[:end_line].should == 20
    options[:require].should == ['torequire']
    options[:help].should be_a_kind_of String
    options[:errors].should be_empty
  end

  describe ':filename' do
    it 'defaults to nil' do
      parse([])[:filename].should be_nil
    end

    it 'is the first non-flag' do
      parse(['a'])[:filename].should == 'a'
      parse(['-x', 'a'])[:filename].should == 'a'
      parse(['a', '-x'])[:filename].should == 'a'
    end

    it 'sets an error if given multiple filenames' do
      parse([]).should_not have_error /name/
      parse(['a']).should_not have_error /Can only have one filename/
      parse(['a', 'b']).should have_error 'Can only have one filename, but had: "a", "b"'
    end
  end

  describe ':start_line' do
    it 'defaults to 1' do
      parse([])[:start_line].should equal 1
    end

    it 'is set with -l and --start-line' do
      parse(['-l', '1'])[:start_line].should == 1
      parse(['--start-line', '12'])[:start_line].should == 12
    end

    it_behaves_like 'it requires a positive int argument', ['-l', '--start-line']
  end

  describe ':end_line' do
    it 'defaults to infinity' do
      parse([])[:end_line].should equal Float::INFINITY
    end

    it 'is set with -L and --end-line' do
      parse(['-L', '1'])[:end_line].should == 1
      parse(['--end-line', '12'])[:end_line].should == 12
    end

    it_behaves_like 'it requires a positive int argument', ['-L', '--end-line']
  end

  it 'swaps start and end line around if they are out of order' do
    parse(%w[-l 2 -L 1])[:start_line].should == 1
    parse(%w[-l 2 -L 1])[:end_line].should == 2
  end

  describe ':result_length' do
    it 'defaults to infinity' do
      parse([])[:result_length].should == Float::INFINITY
    end

    it 'is set with -D and --result-length' do
      parse(['-D',              '10'])[:result_length].should == 10
      parse(['--result-length', '10'])[:result_length].should == 10
    end

    it_behaves_like 'it requires a positive int argument', ['-D', '--result-length']
  end

  describe ':line_length' do
    it 'defaults to infinity' do
      parse([])[:line_length].should == Float::INFINITY
    end

    it 'is set with -d and --line-length' do
      parse(['-d',            '10'])[:line_length].should == 10
      parse(['--line-length', '10'])[:line_length].should == 10
    end

    it_behaves_like 'it requires a positive int argument', ['-d', '--line-length']
  end

  describe :require do
    it 'defaults to an empty array' do
      parse([])[:require].should be_empty
    end

    it '-r and --require sets each required file into the result array' do
      parse(%w[-r f1 --require f2])[:require].should == %w[f1 f2]
    end

    it 'sets an error if not provided with a filename' do
      parse(['--require', 'f']).should_not have_error /-r/
      parse(['-r']).should have_error /-r\b/
      parse(['--require']).should have_error /--require\b/
    end
  end

  describe ':help' do
    it 'defaults to nil' do
      parse([])[:help].should be_nil
    end

    it 'is set to the help screen with -h and --help and -help' do
      parse(['-h'])[:help].should == described_class.help_screen
      parse(['--help'])[:help].should == described_class.help_screen
    end
  end

  describe ':program' do
    it 'defaults to nil' do
      parse([])[:program].should be_nil
    end

    it 'is set with -e or --program, and takes the next arg' do
      parse(['-e', '1'])[:program].should == '1'
      parse(['--program', '1'])[:program].should == '1'
    end

    it 'sets an error if not given a program' do
      parse([]).should_not have_error /-e/
      parse([]).should_not have_error /--program/
      parse(['-e']).should have_error /-e/
      parse(['--program']).should have_error /--program/
    end

    it 'sets an error if a filename is also give' do
      parse(['-e', '1']).should_not have_error /-e/
      parse(['-e', '1', 'abc']).should have_error /"abc"/
    end
  end

  describe':load_path' do
    it 'defaults to an empty array' do
      parse([])[:load_path].should be_empty
    end

    specify '-I and --load-path sets each required file into the result array' do
      parse(%w[-I f1 --load-path f2])[:load_path].should == %w[f1 f2]
    end

    it 'sets an error if not provided with a dir' do
      parse(['--load-path', 'f']).should_not have_error /-I/
      parse(['-I']).should have_error /-I\b/
      parse(['--load-path']).should have_error /--load-path\b/
    end
  end

  describe ':encoding' do
    it 'defaults to nil' do
      parse([])[:encoding].should be_nil
    end

    specify '-K and --encoding sets the encoding to the next argument' do
      parse(%w[-K u])[:encoding].should == 'u'
      parse(%w[--encoding u])[:encoding].should == 'u'
    end

    specify 'with -K, the argument can be placed immediately after it (e.g. -Ku) because Ruby allows this' do
      parse(['-Ku'])[:encoding].should == 'u'
      parse(['-Ku']).should_not have_error /-K/
    end

    it 'sets an error if not provided with an encoding' do
      parse(['-Ku']).should_not have_error /-K/
      parse(['-K u']).should_not have_error /-K/
      parse(['--encoding', 'u']).should_not have_error /--encoding/
      parse(['-K']).should have_error /-K/
      parse(['--encoding']).should have_error /--encoding/
    end
  end

  describe ':as' do
    it 'defaults to nil' do
      parse([])[:as].should be_nil
    end

    it 'can be set with -a and --as' do
      parse(%w[-a   abc])[:as].should == 'abc'
      parse(%w[--as abc])[:as].should == 'abc'
    end

    it 'sets an error if not provided with a filename' do
      parse(%w[-a  f]).should_not have_error /-a/
      parse(%w[-as f]).should_not have_error /--as/
      parse(%w[-a   ]).should have_error /-a/
      parse(%w[--as ]).should have_error /--as/
    end
  end

  describe ':clean' do
    it 'defaults to false' do
      parse([])[:clean].should == false
    end

    it 'can be set with -c and --clean' do
      parse(%w[-c])[:clean].should == true
      parse(%w[--clean])[:clean].should == true
    end
  end

  describe ':version' do
    it 'defaults to false' do
      parse([])[:version].should == false
    end

    it 'can be set with -v and --version' do
      parse(%w[-v])[:version].should == true
      parse(%w[--version])[:version].should == true
    end
  end

  describe ':timeout' do
    it 'defaults to 0' do
      parse([])[:timeout].should == 0
    end

    it_behaves_like 'it requires a non-negative float or int', ['-t', '--timeout']
  end

  describe ':alignment_strategy' do
    AlignFile  = SeeingIsBelieving::Binary::AlignFile
    AlignLine  = SeeingIsBelieving::Binary::AlignLine
    AlignChunk = SeeingIsBelieving::Binary::AlignChunk

    # maybe change the default?
    it 'defaults to AlignChunk' do
      parse([])[:alignment_strategy].should == AlignChunk
    end

    specify '-s and --alignment-strategy sets the alignment strategy' do
      parse(['-s',                   'chunk'])[:alignment_strategy].should == AlignChunk
      parse(['--alignment-strategy', 'chunk'])[:alignment_strategy].should == AlignChunk
    end

    it 'accepts values: file, line, chunk' do
      parse(['-s',  'file'])[:alignment_strategy].should == AlignFile
      parse(['-s',  'line'])[:alignment_strategy].should == AlignLine
      parse(['-s', 'chunk'])[:alignment_strategy].should == AlignChunk
    end

    it 'sets an error if not provided with a strategy, or if provided with an unknown strategy' do
      parse(['-s', 'file']).should_not have_error /alignment-strategy/
      parse(['-s',  'abc']).should     have_error /alignment-strategy/
      parse(['-s'        ]).should     have_error /alignment-strategy/
    end
  end

  describe ':inherit_exit_status' do
    it 'defaults to false' do
      parse([])[:inherit_exit_status].should be_false
    end

    it 'can be set with --inherit-exit-status or -i' do
      parse(['--inherit-exit-status'])[:inherit_exit_status].should be_true
      parse(['-i'])[:inherit_exit_status].should be_true
    end
  end
end

