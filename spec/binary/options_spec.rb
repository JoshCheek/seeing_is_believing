require 'seeing_is_believing/binary/parse_args'
require 'seeing_is_believing/binary/options'

class SeeingIsBelieving
  module Binary
    RSpec.describe Options do
      let(:stdin_data)  { 'stdin data' }
      let(:stdin)       { double 'stdin', read: stdin_data }
      let(:stdout)      { double 'stdout' }
      let(:stderr)      { double 'stderr' }

      let(:file_body)            { 'good file body' }
      let(:nonexisting_filename) { 'badfilename'    }
      let(:existing_filename)    { 'goodfilename'   }

      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:exist?).with(existing_filename).and_return(true)
        allow(File).to receive(:exist?).with(nonexisting_filename).and_return(false)
        allow(File).to receive(:read).with(existing_filename).and_return(file_body)
      end

      def opts(overrides={})
        flags = ParseArgs.call []
        described_class.new(flags.merge(overrides), stdin, stdout, stderr)
      end

      describe '.to_regex' do
        def assert_parses(input, regex)
          expect(described_class.to_regex input).to eq regex
        end

        it 'converts strings into regexes' do
          assert_parses '',    %r()
          assert_parses 'a',   %r(a)
        end

        it 'ignores surrounding slashes' do
          assert_parses '//',  %r()
          assert_parses '/a/', %r(a)
        end

        it 'respects flags after the trailing slash in surrounding slashes' do
          assert_parses '/a/',     %r(a)
          assert_parses '/a//',    %r(a/)
          assert_parses '//a/',    %r(/a)
          assert_parses '/a/i',    %r(a)i
          assert_parses '/a/im',   %r(a)im
          assert_parses '/a/xim',  %r(a)xim
          assert_parses '/a/mix',  %r(a)mix
          assert_parses '/a/mixi', %r(a)mixi
        end

        it 'isn\'t fooled by strings that kinda look regexy' do
          assert_parses '/a',  %r(/a)
          assert_parses 'a/',  %r(a/)
          assert_parses '/',   %r(/)
          assert_parses '/i',  %r(/i)
        end

        it 'does not escape the content' do
          assert_parses 'a\\s+',   %r(a\s+)
          assert_parses '/a\\s+/', %r(a\s+)
        end
      end

      describe 'annotator' do
        it 'annotates every line by default' do
          expect(opts.annotator).to eq AnnotateEveryLine
        end

        it 'annotates xmpfilter-style if xmpfilter_style was set' do
          expect(opts.annotator).to eq AnnotateEveryLine
        end
      end

      describe 'help' do
        let(:overrides) { {short_help_screen: 'short help screen',
                           long_help_screen:  'long help screen'} }

        context 'when the value is not set' do
          before { overrides[:help] = nil }

          it 'does not set print_help?' do
            expect(opts(overrides).print_help?).to eq false
          end
        end

        context 'when the value is "help"' do
          before { overrides[:help] = 'help' }

          it 'sets print_help?' do
            expect(opts(overrides).print_help?).to eq true
          end

          it 'sets the help_screen to the short one' do
            expect(opts(overrides).help_screen).to eq 'short help screen'
          end
        end

        context 'when the value is "help+"' do
          before { overrides[:help] = 'help+' }

          it 'sets print_help?' do
            expect(opts(overrides).print_help?).to eq true
          end

          it 'sets the help screen to the long one' do
            expect(opts(overrides).help_screen).to eq 'long help screen'
          end
        end
      end

      context 'debug' do
        it 'sets a null debugger when false' do
          expect(opts(debug: false).debugger).to_not be_enabled
        end

        it 'sets a debugger to the error stream when true' do
          expect(opts(debug: true).debugger).to be_enabled
          seen = ""
          allow(stderr).to receive(:<<) { |str| seen << str }
          opts(debug: true).debugger.context("oooooooo") { "chills and fever" }
          expect(seen).to include "oooooooo"
          expect(seen).to include "chills and fever"
        end
      end

      context 'markers' do
        # TODO: fix this later to use objs
      end

      context 'timeout' do
        it 'sets timeout to the value' do
          expect(opts(timeout_seconds: 0).timeout_seconds).to eq 0
          expect(opts(timeout_seconds: 1).timeout_seconds).to eq 1
        end
      end

      context 'filename' do
        it 'sets this as the filename' do
          expect(opts(filename: 'somefilename').filename).to eq 'somefilename'
        end

        it 'sets an error when there is a filename and that file does not exist' do
          expect(opts(filename:                  nil).errors).to     be_empty
          expect(opts(filename:    existing_filename).errors).to     be_empty
          expect(opts(filename: nonexisting_filename).errors).to_not be_empty
        end
      end

      context 'filenames' do
        it 'sets an error if more than one filename was provided' do
          expect(opts(filenames: []).errors.join).to_not match /filename/
          expect(opts(filenames: ['a']).errors.join).to_not match /filename/
          expect(opts(filenames: ['a', 'b']).errors.join).to match /filename/
        end

        it 'sets an error if there is a filename and the program was also passed on stdin' do
          matcher = /also specified the filename/
          expect(opts(filename: 'f', program_from_args: 'prog').errors.join).to match matcher
          expect(opts(filename: nil, program_from_args: 'prog').errors.join).to_not match matcher
          expect(opts(filename: 'f', program_from_args: nil   ).errors.join).to_not match matcher
        end
      end

      context 'predicates' do
        it 'sets print_version? when version is true' do
          expect(opts(version: false).print_version?).to eq false
          expect(opts(version: true).print_version?).to eq true
        end

        it 'sets inherit_exit_status when inherit_exit_status is true' do
          expect(opts(inherit_exit_status: false).inherit_exit_status?).to eq false
          expect(opts(inherit_exit_status: true).inherit_exit_status?).to eq true
        end

        it 'sets result_as_json when result_as_json is true' do
          expect(opts(result_as_json: false).result_as_json?).to eq false
          expect(opts(result_as_json: true).result_as_json?).to eq true
        end

        it 'sets print_help when help has a value' do
          expect(opts(help: nil).print_help?).to eq false
          expect(opts(help: 'help').print_help?).to eq true
        end

        it 'sets print_cleaned when clean is set' do
          expect(opts(clean: false).print_cleaned?).to eq false
          expect(opts(clean: true).print_cleaned?).to eq true
        end

        it 'sets file_is_on_stdin when there is no filename and the program is not provided in the args' do
          expect(opts(filename: nil, program_from_args: nil).file_is_on_stdin?).to eq true
          expect(opts(filename: 'f', program_from_args: nil).file_is_on_stdin?).to eq false
          expect(opts(filename: nil, program_from_args: 'p').file_is_on_stdin?).to eq false
        end
      end

      context 'deprecations' do
        it 'is the list of deprecations from the flags' do
          deprecated_arg = ParseArgs::DeprecatedArg.new(explanation: 'do something else', args: ['flag'])
          expect(
            opts(deprecated_args: [deprecated_arg]).deprecations
          ).to include deprecated_arg
        end
      end

      context 'body' do
        it 'is an empty string if we don\'t need the body (when there are errors or we are printing the version, or help)' do
          expect(opts(                              ).body).to_not be_empty
          expect(opts(version:                  true).body).to eq ''
          expect(opts(help:                     true).body).to eq ''
          expect(opts(alignment_strategy: 'nonsense').body).to eq ''
        end

        it 'is the program_from_args if this is provided' do
          expect(opts(program_from_args: 'prog').body).to eq 'prog'
        end

        it 'is stdin if there is no file and no program_from_args' do
          expect(opts(filename: nil, program_from_args: nil).body).to eq stdin_data
        end

        it 'is the file body if the filename is provded and exists' do
          expect(opts(filename: existing_filename).body).to eq file_body
        end

        it 'is an empty string if the provided filename dne' do
          expect(opts(filename: nonexisting_filename).body).to eq ""
        end
      end

      context 'lib_options' do
        def lib_opts(overrides={})
          opts(overrides).lib_options
        end

        it 'returns a hash to be passed to the evaluator' do
          expect(lib_opts).to be_a_kind_of Hash
        end

        specify 'filename is the as option or the provided filename' do
          expect(lib_opts(filename: 'from_fn')[:filename]).to eq 'from_fn'
          expect(lib_opts(as: 'from_as')[:filename]).to eq 'from_as'
          expect(lib_opts(as: 'from_as', filename: 'from_fn')[:filename]).to eq 'from_as'
        end

        specify 'the stdin we will pass to the program is an empty string when the program was provided on stdin, otherwise is the provided stdin' do
          expect(lib_opts(filename: nil, program_from_args: nil)[:stdin]).to eq '' # string and stream both satisfy the #each_char interface
          expect(lib_opts(filename: nil, program_from_args: '1')[:stdin]).to eq stdin
        end

        specify 'require includes the matrix first, plus any other required files' do
          expect(lib_opts(require: ['somefile'])[:require]).to eq ['seeing_is_believing/the_matrix', 'somefile']
        end

        specify 'load_path is the load_path, with the full path to sib\'s lib added' do
          path_to_lib = File.expand_path('../../../lib', __FILE__)
          expect(lib_opts(load_path: ['somepath'])[:load_path]).to eq [path_to_lib, 'somepath']
        end

        specify 'encoding is set to the encoding' do
          expect(lib_opts()[:encoding]).to eq nil
          expect(lib_opts(encoding: 'someencoding')[:encoding]).to eq 'someencoding'
        end

        specify 'timeout_seconds is set to timeout_seconds' do
          expect(lib_opts(timeout_seconds: 1.2)[:timeout_seconds]).to eq 1.2
        end

        specify 'debugger is the same as the toplevel debugger' do
          options = opts()
          expect(options.lib_options[:debugger]).to equal options.debugger
        end

        specify 'max_captures_per_line is max_captures_per_line' do
          expect(lib_opts(max_captures_per_line: 12345)[:max_captures_per_line]).to eq 12345
        end

        specify 'annotate is the annotator\'s expression wrapper' do
          expect(lib_opts[:annotate]).to eq Annotate
          expect(lib_opts(xmpfilter_style: true)[:annotate]).to be_a_kind_of Proc
        end
      end

      context 'annotator_options' do
        def annotator_opts(overrides={})
          opts(overrides).annotator_options
        end

        it 'sets alignment_strategy to the provided alignment strategy' do
          expect(annotator_opts(alignment_strategy: 'chunk')[:alignment_strategy]).to eq AlignChunk
          expect(annotator_opts(alignment_strategy: 'file' )[:alignment_strategy]).to eq AlignFile
          expect(annotator_opts(alignment_strategy: 'line' )[:alignment_strategy]).to eq AlignLine
        end

        it 'sets an error if the requested alignment strategy is not known, or not provided' do
          expect(opts(alignment_strategy: 'chunk').errors.join).to_not include 'alignment-strategy'
          expect(opts(alignment_strategy: 'nonsense').errors.join).to include 'alignment-strategy does not know'
          expect(opts(alignment_strategy: nil).errors.join).to include 'alignment-strategy expected an alignment strategy'
        end

        it 'sets the debugger to the toplevel debugger' do
          options = opts()
          expect(options.annotator_options[:debugger]).to equal options.debugger
        end

        # TODO: markers
        it 'sets max_line_length to the max_line_length' do
          expect(annotator_opts(max_line_length: 123321)[:max_line_length]).to eq 123321
        end

        it 'sets max_result_length to the max_result_length' do
          expect(annotator_opts(max_result_length: 99889)[:max_result_length]).to eq 99889
        end
      end

      it 'has a fancy inspect that shows predicates and attributes on multiple lines' do
        inspected = opts.inspect
        expect(inspected).to include "PREDICATES"
        expect(inspected).to include "ATTRIBUTES"
        expect(inspected.lines.to_a.length).to be > 1
        inspected.lines.each do |line|
          expect(line.length).to be < 80 # truncate output so it doesn't get spammy
        end
      end
    end
  end
end
