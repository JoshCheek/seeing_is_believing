require 'seeing_is_believing/arg_parser'

describe SeeingIsBelieving::ArgParser do
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

  specify 'unknown options set an error' do
    parse(['--abc']).should have_error 'Unknown option: "--abc"'
    parse(['-a']).should have_error 'Unknown option: "-a"'
  end

  example 'example: all the args' do
    options = parse(%w[filename -l 12 -L 20 -h])
    options[:filename].should == 'filename'
    options[:start_line].should == 12
    options[:end_line].should == 20
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

    it 'sets an error if it cannot be turned into a positive integer' do
      line_error_assertions = lambda do |flag|
        parse([flag, '1']).should_not have_error /#{flag}/
        parse([flag, '0']).should have_error /#{flag}/
        parse([flag, 'a']).should have_error /#{flag}/
        parse([flag, '']).should have_error /#{flag}/
        parse([flag, '1.0']).should have_error /#{flag}/
        parse([flag]).should have_error /#{flag}/
      end
      line_error_assertions['-l']
      line_error_assertions['--start-line']
    end
  end

  describe ':end_line' do
    it 'defaults to infinity' do
      parse([])[:end_line].should equal Float::INFINITY
    end

    it 'is set with -L and --end-line' do
      parse(['-L', '1'])[:end_line].should == 1
      parse(['--end-line', '12'])[:end_line].should == 12
    end

    it 'sets an error if it cannot be turned into an integer' do
      line_error_assertions = lambda do |flag|
        parse([flag, '1']).should_not have_error /#{flag}/
        parse([flag, 'a']).should have_error /#{flag}/
        parse([flag, '']).should have_error /#{flag}/
        parse([flag]).should have_error /#{flag}/
      end
      line_error_assertions['-L']
      line_error_assertions['--end-line']
    end
  end

  it 'swaps start and end line around if they are out of order' do
    parse(%w[-l 2 -L 1])[:start_line].should == 1
    parse(%w[-l 2 -L 1])[:end_line].should == 2
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
end
