require 'spec_helper'
require 'seeing_is_believing/binary/config'


RSpec.describe SeeingIsBelieving::Binary::Config do
  RSpec::Matchers.define :have_error do |error_assertion|
    match do |config|
      config.errors.find do |error|
        case error_assertion
        when Regexp
          error_assertion =~ error.explanation
        else
          error.explanation.include? error_assertion
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

  let(:matrix_file)     { 'seeing_is_believing/the_matrix' }
  let(:default_markers) { SeeingIsBelieving::Binary::Markers.new }

  def parse(args)
    described_class.new.parse_args(args)
  end

  def assert_deprecated(flag, *args)
    deprecated_args = parse([flag, *args]).deprecations
    expect(deprecated_args.size).to eq 1
    deprecated = deprecated_args.first
    expect(deprecated.args).to eq [flag, *args]
    expect(deprecated.explanation).to be_a_kind_of String
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

  describe 'parsing from args' do
    it 'does not mutate the input array' do
      ary = ['a']
      parse(ary)
      expect(ary).to eq ['a']
    end

    it 'correctly parses multiple args' do
      config = parse(%w[filename -h -r torequire])
      expect(config.filename).to eq 'filename'
      expect(config.lib_options.require_files).to include 'torequire'
      expect(config.print_help?).to eq true
      expect(config.errors).to be_empty
    end

    # This sill dance is b/c equality assertions are annoying and not relevant anywhere else
    # Don't like having to go implement this stuff just for a few high-level tests.
    def flat_options(config)
      flat_keys = config.keys - [:lib_options, :annotator_options]
      flat_keys.each_with_object({}) { |key, hash| hash[key] = config[key] }
    end
    def assert_same_flat_opts(args1, args2)
      flatopts1 = flat_options parse args1
      flatopts2 = flat_options parse args2
      expect(flatopts1).to eq flatopts2
    end
    it 'can interpret conjoined short-flags' do
      assert_same_flat_opts ['-hjg'], ['-h', '-j', '-g'] # help, json, debug
    end
    it 'can interpret conjoined short-flags where one of them is h+' do
      assert_same_flat_opts ['-h+jg'], ['-h+', '-j',  '-g']
      assert_same_flat_opts ['-jh+g'], ['-j',  '-h+', '-g']
      assert_same_flat_opts ['-jgh+'], ['-j',  '-g',  '-h+']
    end

    specify 'unknown options set an error' do
      expect(parse(['--xyz'  ])).to have_error '--xyz is not an option'
      expect(parse(['-y'     ])).to have_error '-y is not an option'
      expect(parse(['-y', 'b'])).to have_error '-y is not an option'
      expect(parse(['-+h'    ])).to have_error '-+ is not an option'
    end

    describe 'filename and lib_options.filename' do
      specify 'default to nil' do
        expect(parse([]).filename).to be_nil
        expect(parse([]).lib_options.filename).to be_nil
      end

      specify 'both filename and lib_options.filename are set when a filename is seen' do
        config = parse ['a']
        expect(config.filename).to eq 'a'
        expect(config.lib_options.filename).to eq 'a'
      end

      specify 'the filename is a nonflag / nonarg' do
        # nonflag / nonarg
        expect(parse(['-x']).filename).to eq nil
        expect(parse(['-n', '3']).filename).to eq nil

        # find it amidst flags/largs
        expect(parse(['a']).filename).to eq 'a'
        expect(parse(['-x', 'a']).filename).to eq 'a'
        expect(parse(['a', '-x']).filename).to eq 'a'
        expect(parse(['a', '-n', '3']).filename).to eq 'a'
        expect(parse(['-n', '3', 'a', '-r', 'f']).filename).to eq 'a'
      end

      it 'does not confuse filenames with unknown args' do
        unknown_arg = '-y'
        expect(parse([unknown_arg]).filename).to be_nil
      end

      it 'sets an error if given multiple filenames' do
        expect(parse([]).errors).to be_empty
        expect(parse(['a']).errors).to be_empty
        expect(parse(['a', 'b'])).to have_error /"a", "b"/
      end

      specify '-a and --as set lib_options.filename, but not filename' do
        expect(parse(%w[-a   abc]).filename).to eq nil
        expect(parse(%w[--as abc]).filename).to eq nil
        expect(parse(%w[-a   abc]).lib_options.filename).to eq 'abc'
        expect(parse(%w[--as abc]).lib_options.filename).to eq 'abc'
      end

      specify '-a and --as always win over a filename' do
        config = parse(['fn', '-a', 'as'])
        expect(config.filename).to eq 'fn'
        expect(config.lib_options.filename).to eq 'as'

        config = parse(['-a', 'as', 'fn'])
        expect(config.filename).to eq 'fn'
        expect(config.lib_options.filename).to eq 'as'
      end

      it 'sets an error if -a/--as are given without the filename to execute as' do
        expect(parse(%w[-a  f])).to_not have_error /-a/
        expect(parse(%w[-as f])).to_not have_error /--as/
        expect(parse(%w[-a   ])).to have_error /-a/
        expect(parse(%w[--as ])).to have_error /--as/
      end
    end


    describe 'annotator_options.max_result_length' do
      it 'defaults to infinity' do
        expect(parse([]).annotator_options.max_result_length).to eq Float::INFINITY
      end

      it 'is set with -D and --result-length' do
        expect(parse(['-D',              '10']).annotator_options.max_result_length).to eq 10
        expect(parse(['--result-length', '10']).annotator_options.max_result_length).to eq 10
      end

      it_behaves_like 'it requires a positive int argument', ['-D', '--result-length']
    end

    describe 'annotator_options.max_line_length' do
      it 'defaults to infinity' do
        expect(parse([]).annotator_options.max_line_length).to eq Float::INFINITY
      end

      it 'is set with -d and --line-length' do
        expect(parse(['-d',            '10']).annotator_options.max_line_length).to eq 10
        expect(parse(['--line-length', '10']).annotator_options.max_line_length).to eq 10
      end

      it_behaves_like 'it requires a positive int argument', ['-d', '--line-length']
    end

    describe 'lib_options.require_files' do
      it 'defaults to the matrix file array' do
        expect(parse([]).lib_options.require_files).to eq [matrix_file]
      end

      specify '-r and --require set an error if not provided with a filename' do
        expect(parse(['--require', 'f'])).to_not have_error /-r/
        expect(parse(['-r'])).to have_error /-r\b/
        expect(parse(['--require'])).to have_error /--require\b/
      end

      specify '-r and --require add the filename into the result array' do
        expect(parse(%w[-r f1 --require f2]).lib_options.require_files).to eq [matrix_file, 'f1', 'f2']
      end
    end

    describe 'print_help? and help_screen' do
      let(:help_screen)          { SeeingIsBelieving::Binary.help_screen          default_markers }
      let(:help_screen_extended) { SeeingIsBelieving::Binary.help_screen_extended default_markers }

      specify 'print_help? defaults to false' do
        expect(parse([]).print_help?).to eq false
      end

      specify 'help_screen defaults to the short help screen' do
        expect(parse([]).help_screen).to eq help_screen
      end

      it 'print_help? is set to true with -h, --help, -h+, and --help+' do
        expect(parse(['-h']).print_help?).to eq true
        expect(parse(['-h+']).print_help?).to eq true
        expect(parse(['--help']).print_help?).to eq true
        expect(parse(['--help+']).print_help?).to eq true
      end

      specify '-h and --help set help_screen to the short help screen' do
        expect(parse(['-h']).help_screen).to eq help_screen
        expect(parse(['--help']).help_screen).to eq help_screen
      end

      specify '-h+ and --help+ set help_screen to the extended help screen' do
        expect(parse(['-h+']).help_screen).to eq help_screen_extended
        expect(parse(['--help+']).help_screen).to eq help_screen_extended
      end
    end


    describe 'body' do
      it 'defaults to nil' do
        expect(parse([]).body).to eq nil
      end

      it 'is set by an arg to -e and --program' do
        expect(parse(['-e', '1']).body).to eq '1'
        expect(parse(['--program', '1']).body).to eq '1'
      end

      it 'sets an error if -e and --program are not given an arg' do
        expect(parse([])).to_not have_error /-e/
        expect(parse([])).to_not have_error /--program/
        expect(parse(['-e', 'body'])).to_not have_error /-e/
        expect(parse(['-e'        ])).to     have_error /-e/
        expect(parse(['--program', 'body'])).to_not have_error /--program/
        expect(parse(['--program'        ])).to     have_error /--program/
      end
    end

    describe'lib_options.load_path_dirs' do
      let(:lib_path) { File.expand_path '../../../lib', __FILE__ }

      it 'defaults to sib\'s lib path' do
        expect(parse([]).lib_options.load_path_dirs).to eq [lib_path]
      end

      specify '-I and --load-path add their arguments to it' do
        expect(parse(%w[-I f1 --load-path f2]).lib_options.load_path_dirs).to eq [lib_path, 'f1', 'f2']
      end

      it 'sets an error if not provided with a dir' do
        expect(parse(['--load-path', 'f'])).to_not have_error /--load-path/
        expect(parse(['-I'])).to have_error /-I\b/
        expect(parse(['--load-path'])).to have_error /--load-path\b/
      end
    end

    describe 'lib_options.encoding' do
      it 'defaults to nil' do
        expect(parse([]).lib_options.encoding).to be_nil
      end

      specify '-K and --encoding sets the encoding to the next argument' do
        expect(parse(%w[-K u]).lib_options.encoding).to eq 'u'
        expect(parse(%w[--encoding u]).lib_options.encoding).to eq 'u'
      end

      specify 'with -K, the argument can be placed immediately after it (e.g. -Ku) because Ruby allows this' do
        expect(parse(['-Ku']).lib_options.encoding).to eq 'u'
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

    describe '.print_cleaned?' do
      it 'defaults to false' do
        expect(parse([]).print_cleaned?).to eq false
      end

      it 'can be set with -c and --clean' do
        expect(parse(%w[-c]).print_cleaned?).to eq true
        expect(parse(%w[--clean]).print_cleaned?).to eq true
      end
    end

    describe 'print_version?' do
      it 'defaults to false' do
        expect(parse([]).print_version?).to eq false
      end

      it 'can be set with -v and --version' do
        expect(parse(%w[-v]).print_version?).to eq true
        expect(parse(%w[--version]).print_version?).to eq true
      end
    end

    describe 'timeout and lib_options.timeout_seconds' do
      it 'defaults to 0 (never timeout)' do
        expect(parse([]).timeout_seconds).to eq 0
        expect(parse([]).lib_options.timeout_seconds).to eq 0
      end

      it 'can be set with -t and --timeout-seconds' do
        expect(parse(['-t', '1.1']).timeout_seconds).to eq 1.1
        expect(parse(['-t', '1.1']).lib_options.timeout_seconds).to eq 1.1
        expect(parse(['--timeout-seconds', '1.2']).lib_options.timeout_seconds).to eq 1.2
      end

      it 'can be set with the deprecated flag --timeout' do
        expect(parse(['--timeout', '1.3']).lib_options.timeout_seconds).to eq 1.3
        assert_deprecated '--timeout', 1.4
      end

      it_behaves_like 'it requires a non-negative float or int', ['-t', '--timeout-seconds', '--timeout']
    end

    describe 'annotator_options.alignment_strategy' do
      let(:align_chunk) { SeeingIsBelieving::Binary::AlignChunk }
      let(:align_file)  { SeeingIsBelieving::Binary::AlignFile  }
      let(:align_line)  { SeeingIsBelieving::Binary::AlignLine  }

      it 'defaults to AlignChunk' do
        expect(parse([]).annotator_options.alignment_strategy)
          .to eq align_chunk
      end

      specify '-s and --alignment-strategy sets the alignment strategy' do
        expect(parse(['-s', 'file']).annotator_options.alignment_strategy)
          .to eq align_file

        expect(parse(['--alignment-strategy', 'file']).annotator_options.alignment_strategy)
          .to eq align_file
      end

      it 'accepts values: file, line, chunk' do
        expect(parse(['-s',  'file']).annotator_options.alignment_strategy).to eq align_file
        expect(parse(['-s',  'line']).annotator_options.alignment_strategy).to eq align_line
        expect(parse(['-s', 'chunk']).annotator_options.alignment_strategy).to eq align_chunk
      end

      it 'sets an error if not provided with a strategy' do
        expect(parse(['-s'])).to have_error /-s/
        expect(parse(['-s', 'file'])).to_not have_error /-s/
      end

      it 'sets an error if provided with an unknown alignment strategy' do
        expect(parse(['-s', 'file'])).to_not have_error '-s'
        expect(parse(['-s', 'unknown'])).to have_error '-s', 'expected one of'
      end
    end

    describe 'inherit_exitstatus?' do
      it 'defaults to false' do
        expect(parse([]).inherit_exitstatus?).to eq false
      end

      it 'can be set with --inherit-exitstatus, -i' do
        expect(parse(['--inherit-exitstatus']).inherit_exitstatus?).to be true
        expect(parse(['-i']).inherit_exitstatus?).to be true
      end

      it 'can be set with the deprecated --inherit-exit-status' do
        expect(parse(['--inherit-exit-status']).inherit_exitstatus?).to be true
        assert_deprecated '--inherit-exit-status'
      end
    end

    describe 'annotator and lib_options.rewrite_code' do
      specify 'annotator defaults to AnnotateEveryLine' do
        expect(parse([]).annotator).to be SeeingIsBelieving::Binary::AnnotateEveryLine
      end

      specify 'annotator can be set to AnnotateMarkedLines with --xmpfilter-style or -x' do
        expect(parse(['--xmpfilter-style']).annotator).to eq SeeingIsBelieving::Binary::AnnotateMarkedLines
        expect(parse(['-x']).annotator).to eq SeeingIsBelieving::Binary::AnnotateMarkedLines
      end

      specify 'lib_options.rewrite_code is set to the annotator\'s expression wrapper' do
        config = parse []
        expect(config.lib_options.rewrite_code)
          .to eq config.annotator.expression_wrapper(config.markers)

        # not a great test, but the cukes hit its actual behaviour
        expect(parse(['-x']).lib_options.rewrite_code).to be_a_kind_of Proc
      end
    end

    describe 'debug?' do
      specify 'debug? defaults to a false' do
        expect(parse([])[:debug]).to eq false
      end

      specify '-g and --debug set debug? to true' do
        expect(parse(['-g']).debug?).to eq true
        expect(parse(['--debug']).debug?).to eq true
      end
    end

    describe '--shebang' do
      it 'is added to the list of deprecated flags' do
        assert_deprecated '--shebang', 'not_ruby'
      end

      it 'sets an error if not given a next arg to execute' do
        expect(parse([])).to_not have_error /--shebang/
        expect(parse(['--shebang', 'arg'])).to_not have_error /--shebang/
        expect(parse(['--shebang'])).to have_error /--shebang/
      end
    end

    describe 'lib_options.max_line_captures' do
      it 'defaults to infinity' do
        expect(parse([]).lib_options.max_line_captures).to eq Float::INFINITY
      end

      it 'can be set with --max-line-captures or -n' do
        expect(parse(['-n', '10']).lib_options.max_line_captures).to eq 10
        expect(parse(['--max-line-captures', '10']).lib_options.max_line_captures).to eq 10
      end

      it 'can be set with the deprecated flag --number-of-captures' do
        expect(parse(['--number-of-captures', '12']).lib_options.max_line_captures).to eq 12
        assert_deprecated '--number-of-captures', '12'
        assert_deprecated '--number-of-captures'
      end

      it_behaves_like 'it requires a positive int argument', ['-n', '--max-line-captures', '--number-of-captures']
    end

    describe 'result_as_json?' do
      it 'defaults to false' do
        expect(parse([]).result_as_json?).to eq false
      end

      it 'can be enabled with --json or -j' do
        expect(parse(['--json']).result_as_json?).to eq true
        expect(parse(['-j']).result_as_json?).to eq true
      end

      it 'sets an error if specified with xmpfilter' do
        expect(parse(['--json'])).to_not have_error /json/
        expect(parse(['--json', '-x'])).to have_error /json/
        expect(parse(['--json', '--xmpfilter-style'])).to have_error /json/
        expect(parse(['-x', '--json'])).to have_error /json/
        expect(parse(['--xmpfilter-style', '--json'])).to have_error /json/
        expect(parse(['-j', '-x'])).to have_error /json/
        expect(parse(['-j', '-x'])).to have_error /xmpfilter/
      end
    end

    describe 'markers' do
      it 'defaults to a hash with :value, :exception, :stdout, and :stderr' do
        expect(default_markers.keys).to eq [:value, :exception, :stdout, :stderr]
      end

      specify 'each default marker regex can re-find the the marker' do
        default_markers.each do |name, marker|
          comment   = "#{marker.prefix}abc"
          extracted = comment[marker.regex]
          expect(extracted).to eq(marker.prefix)
        end
      end

      it('defaults :value     to "# => "') { expect(default_markers.value    .prefix).to eq "# => " }
      it('defaults :exception to "# ~> "') { expect(default_markers.exception.prefix).to eq "# ~> " }
      it('defaults :stdout    to "# >> "') { expect(default_markers.stdout   .prefix).to eq "# >> " }
      it('defaults :stderr    to "# !> "') { expect(default_markers.stderr   .prefix).to eq "# !> " }
    end
  end

  describe 'print_event_stream?' do
    it 'print_event_stream? is false by default' do
      expect(parse([]).print_event_stream?).to eq false
    end
    it 'print_event_stream? can be turned on with --stream' do
      expect(parse(['--stream']).print_event_stream?).to eq true
    end
    it 'adds an error if --stream is used with --json' do
      expect(parse(['--stream'])).to_not have_error '--stream'
      expect(parse(['--stream', '--json'])).to have_error '--stream'
      expect(parse(['--json', '--stream'])).to have_error '--stream'
    end
    it 'adds an error if --stream is used with -x or --xmpfilter-style' do
      expect(parse(['--stream'])).to_not have_error '--stream'
      expect(parse(['--stream', '-x'])).to have_error '--stream'
      expect(parse(['-x', '--stream'])).to have_error '--stream'
      expect(parse(['--xmpfilter-style', '--stream'])).to have_error '--stream'
    end
  end


  describe '.finalize' do
    let(:stdin_data) { 'stdin data' }
    let(:stdin)      { object_double $stdin, read: stdin_data }
    let(:stdout)     { object_double $stdout }
    let(:stderr)     { object_double $stderr }

    let(:file_class)           { class_double File }
    let(:nonexisting_filename) { 'badfilename'    }
    let(:existing_filename)    { 'goodfilename'   }
    let(:file_body)            { 'good file body' }

    before do
      allow(file_class).to receive(:exist?).with(existing_filename).and_return(true)
      allow(file_class).to receive(:exist?).with(nonexisting_filename).and_return(false)
      allow(file_class).to receive(:read).with(existing_filename).and_return(file_body)
    end

    def call(attrs={})
      described_class.new(attrs).finalize(stdin, stdout, stderr, file_class)
    end

    describe 'additional errors' do
      it 'sets an error if given a filename and a program body -- cannot have two body sources' do
        allow(file_class).to receive(:exist?).with('f')
        matcher = /program body and a filename/
        expect(call filename: 'f', body: 'b').to     have_error matcher
        expect(call filename: 'f', body: 'b').to     have_error matcher
        expect(call filename: nil, body: 'b').to_not have_error matcher
        expect(call filename: 'f', body: nil).to_not have_error matcher
      end

      it 'sets an error if the provided filename DNE' do
        expect(call filename: existing_filename).to_not have_error /filename/
        expect(call filename: nonexisting_filename).to  have_error /filename/
      end
    end

    describe 'setting the body' do
      it 'does not override the if already set e.g. with -e' do
        expect(call(body: 'b', filename: nil).body).to eq 'b'
      end

      it 'is the file body if the filename is provded and exists' do
        expect(call(body: nil, filename: existing_filename).body)
          .to eq file_body
      end

      it 'is an empty string if the filename is provided but DNE' do
        expect(call(body: nil, filename: nonexisting_filename).body)
          .to eq nil
      end

      it 'reads the body from stdin if not given a filename or body' do
        expect(call(body: nil, filename: nil).body).to eq stdin_data
      end

      it 'is set to an empty string when we aren\'t evaluating (e.g. when printing version info)' do
        expect(call(                    ).body).to be_a_kind_of String
        expect(call(print_version:  true).body).to eq ''
        expect(call(print_help:     true).body).to eq ''
        expect(call(errors:        ['e']).body).to eq ''
      end
    end

    describe 'lib_options.stdin' do
      let(:default) { SeeingIsBelieving::Options.new.stdin }

      it 'is the default when we aren\'t evaluating' do
        [ {errors: ['e']},
          {filename: existing_filename, body: 'b'},
          {filename: nonexisting_filename},
          {print_version: true},
          {print_help: true},
        ].each do |overrides|
          expect(call(overrides).lib_options.stdin).to eq default
        end
      end

      it 'is the default when the program was taken off stdin' do
        expect(call.lib_options.stdin).to eq default
        expect(call(body: 'b').lib_options.stdin).to_not eq default
      end

      it 'is the stdin stream when the program body was provided' do
        expect(call(body: 'b').lib_options.stdin).to eq stdin
      end

      it 'is the stdin stream when the program was pulled from a file' do
        expect(call(filename: existing_filename).lib_options.stdin).to eq stdin
        expect(call(filename: nonexisting_filename).lib_options.stdin).to eq default
      end
    end

    describe 'lib_options.event_handler' do
      it 'is an ObserverUpdateResult when print_event_stream? is false' do
        expect(call(print_event_stream: false).lib_options.event_handler)
          .to be_an_instance_of SeeingIsBelieving::EventStream::ObserverUpdateResult
      end
      it 'is an ObserverStreamJsonEvents to stdout when print_event_stream? is true' do
        handler = call(print_event_stream: true).lib_options.event_handler
        expect(handler).to be_an_instance_of SeeingIsBelieving::EventStream::ObserverStreamJsonEvents
        expect(handler.stream).to eq stdout
      end
    end

    describe 'debugger, lib_options.debugger' do
      specify 'default to a null debugger' do
        handler = call
        expect(handler.debugger).to_not be_enabled
        expect(handler.lib_options.debugger).to_not be_enabled
      end

      specify 'are set to debug to stderr when debug? is true' do
        handler = call debug: true
        expect(handler.debugger).to be_enabled
        expect(handler.debugger.stream).to eq stderr
        expect(handler.lib_options.debugger).to equal handler.debugger
      end
    end
  end
end
