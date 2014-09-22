require 'seeing_is_believing/binary/parse_args'
require 'seeing_is_believing/binary/interpret_flags'

class SeeingIsBelieving
  module Binary
    RSpec.describe 'SeeingIsBelieving::Binary::InterpretFlags' do
      let(:stdin_data)  { 'stdin data' }
      let(:stdin)       { double 'stdin', read: stdin_data }
      let(:stdout)      { double 'stdout' }

      let(:file_body)            { 'good file body' }
      let(:nonexisting_filename) { 'badfilename'    }
      let(:existing_filename)    { 'goodfilename'   }

      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:exist?).with(existing_filename).and_return(true)
        allow(File).to receive(:exist?).with(nonexisting_filename).and_return(false)
        allow(File).to receive(:read).with(existing_filename).and_return(file_body)
      end

      def call(overrides={})
        flags = ParseArgs.call []
        InterpretFlags.new(flags.merge(overrides), stdin, stdout)
      end

      describe 'annotator' do
        it 'annotates every line by default' do
          expect(call.annotator).to eq AnnotateEveryLine
        end

        it 'annotates xmpfilter-style if xmpfilter_style was set' do
          expect(call.annotator).to eq AnnotateEveryLine
        end
      end

      describe 'help' do
        let(:overrides) { {short_help_screen: 'short help screen',
                           long_help_screen:  'long help screen'} }

        context 'when the value is not set' do
          before { overrides[:help] = nil }

          it 'does not set print_help?' do
            expect(call(overrides).print_help?).to eq false
          end
        end

        context 'when the value is "help"' do
          before { overrides[:help] = 'help' }

          it 'sets print_help?' do
            expect(call(overrides).print_help?).to eq true
          end

          it 'sets the help_screen to the short one' do
            expect(call(overrides).help_screen).to eq 'short help screen'
          end
        end

        context 'when the value is "help+"' do
          before { overrides[:help] = 'help+' }

          it 'sets print_help?' do
            expect(call(overrides).print_help?).to eq true
          end

          it 'sets the help screen to the long one' do
            expect(call(overrides).help_screen).to eq 'long help screen'
          end
        end
      end

      context 'debug' do
        it 'sts a null debugger when false' do
          expect(call(debug: false).debugger).to_not be_enabled
        end

        it 'sets a debugger to the output stream when true' do
          expect(call(debug: true).debugger).to be_enabled
        end
      end

      context 'markers' do
        # TODO: fix this later to use objs
      end

      context 'timeout' do
        it 'sets timeout to the value' do
          expect(call(timeout: 0).timeout).to eq 0 # TODO: Should the interpretation of 0 move up from flags to here?
          expect(call(timeout: 1).timeout).to eq 1
        end
      end

      context 'shebang' do
        it 'sets shebang to the value' do
          expect(call(shebang: 'whatevz').shebang).to eq 'whatevz'
        end
      end

      context 'filename' do
        it 'sets this as the filename' do
          expect(call(filename: 'somefilename').filename).to eq 'somefilename'
        end
      end

      context 'filenames' do
        it 'sets an error if more than one filename was provided' do
          expect(call(filenames: []).errors.join).to_not match /filename/
          expect(call(filenames: ['a']).errors.join).to_not match /filename/
          expect(call(filenames: ['a', 'b']).errors.join).to match /filename/
        end

        it 'sets an error if there is a filename and the program was also passed on stdin' do
          matcher = /also specified the filename/
          expect(call(filename: 'f', program_from_args: 'prog').errors.join).to match matcher
          expect(call(filename: nil, program_from_args: 'prog').errors.join).to_not match matcher
          expect(call(filename: 'f', program_from_args: nil   ).errors.join).to_not match matcher
        end
      end

      context 'predicates' do
        it 'sets print_version? when version is true' do
          expect(call(version: false).print_version?).to eq false
          expect(call(version: true).print_version?).to eq true
        end

        it 'sets inherit_exit_status when inherit_exit_status is true' do
          expect(call(inherit_exit_status: false).inherit_exit_status?).to eq false
          expect(call(inherit_exit_status: true).inherit_exit_status?).to eq true
        end

        it 'sets result_as_json when result_as_json is true' do
          expect(call(result_as_json: false).result_as_json?).to eq false
          expect(call(result_as_json: true).result_as_json?).to eq true
        end

        it 'sets print_help when help has a value' do
          expect(call(help: nil).print_help?).to eq false
          expect(call(help: 'help').print_help?).to eq true
        end

        it 'sets print_cleaned when clean is set' do
          expect(call(clean: false).print_cleaned?).to eq false
          expect(call(clean: true).print_cleaned?).to eq true
        end

        it 'sets provided_filename_dne when there is a filename and that file does not exist' do
          expect(call(filename: nonexisting_filename).provided_filename_dne?).to eq true
          expect(call(filename: existing_filename).provided_filename_dne?).to eq false
          expect(call(filename: nil).provided_filename_dne?).to eq false
        end

        it 'sets file_is_on_stdin when there is no filename and the program is not provided in the args' do
          expect(call(filename: nil, program_from_args: nil).file_is_on_stdin?).to eq true
          expect(call(filename: 'f', program_from_args: nil).file_is_on_stdin?).to eq false
          expect(call(filename: nil, program_from_args: 'p').file_is_on_stdin?).to eq false
        end
      end

      context 'body' do
        it 'is an empty string if we\'re going to print the version or help instead of the program' do
          expect(call(version: true).body).to eq ''
          expect(call(help:    true).body).to eq ''
        end

        it 'is the program_from_args if this is provided' do
          expect(call(program_from_args: 'prog').body).to eq 'prog'
        end

        it 'is stdin if there is no file and no program_from_args' do
          expect(call(filename: nil, program_from_args: nil).body).to eq stdin_data
        end

        it 'is the file body if the filename is provded and exists' do
          expect(call(filename: existing_filename).body).to eq file_body
        end

        it 'is an empty string if the provided filename dne' do
          expect(call(filename: nonexisting_filename).body).to eq ""
        end
      end

      context 'prepared_body' do
        it 'is the body after being run throught he annotator\'s prepare method' do
          expect(call(program_from_args: '1+1 # => ').prepared_body).to eq '1+1'
        end
      end

      context 'lib_options' do
        def call(overrides={})
          super(overrides).lib_options
        end

        it 'returns a hash to be passed to the evaluator' do
          expect(call).to be_a_kind_of Hash
        end

        specify 'evaluate_with is EvaluateByMovingFiles by default' do
          expect(call[:evaluate_with]).to eq EvaluateByMovingFiles
        end

        specify 'evaluate_with is EvaluateWithEvalIn if safe is set' do
          expect(call(safe: true)[:evaluate_with]).to eq EvaluateWithEvalIn
        end

        specify 'filename is the as option or the provided filename' do
          expect(call(filename: 'from_fn')[:filename]).to eq 'from_fn'
          expect(call(as: 'from_as')[:filename]).to eq 'from_as'
          expect(call(as: 'from_as', filename: 'from_fn')[:filename]).to eq 'from_as'
        end

        specify 'ruby_executable is the shebang' do
          expect(call(shebang: 'shebangprog')[:ruby_executable]).to eq 'shebangprog'
        end

        specify 'stdin is empty when the program is on stdin, and is stdin otherwise' do
          # NOTE: the lib will normalize this into a stream
          expect(call(filename: nil, program_from_args: nil)[:stdin]).to eq ''
          expect(call(filename: nil, program_from_args: '1')[:stdin]).to eq stdin
        end

        # TODO: Add cuke where required file prints
        specify 'require includes the matrix first, plus any other required files' do
          expect(call(require: ['somefile'])[:require]).to eq ['seeing_is_believing/the_matrix', 'somefile']
        end

        # TODO: This is prob not ture for eval_in... maybe let the evaluators provide defaults?
        specify 'load_path is the load_path, with the full path to sib\'s lib added' do
          path_to_lib = File.expand_path('../../../lib', __FILE__)
          expect(call(load_path: ['somepath'])[:load_path]).to eq [path_to_lib, 'somepath']
        end

        # TODO: Default this to utf-8
        specify 'encoding is set to the encoding' do
          expect(call(encoding: 'someencoding')[:encoding]).to eq 'someencoding'
        end

        specify 'timeout is set to timeout' do
          expect(call(timeout: 1.2)[:timeout]).to eq 1.2
        end

        specify 'debugger is the same as the toplevel debugger' do
          options = InterpretFlags.new(ParseArgs.call([]), stdin, stdout)
          expect(options.lib_options[:debugger]).to equal options.debugger
        end

        specify 'number_of_captures is number_of_captures' do
          expect(call(number_of_captures: 12345)[:number_of_captures]).to eq 12345
        end

        specify 'record_expressions is the annotator\'s expression wrapper' do
          expect(call[:record_expressions]).to eq InspectExpressions
          expect(call(xmpfilter_style: true)[:record_expressions]).to be_a_kind_of Proc
        end
      end

      context 'annotator_options' do
        def call(overrides={})
          super(overrides).annotator_options
        end

        it 'sets alignment_strategy to the provided alignment strategy' do
          expect(call(alignment_strategy: 'chunk')[:alignment_strategy]).to eq AlignChunk
          expect(call(alignment_strategy: 'file' )[:alignment_strategy]).to eq AlignFile
          expect(call(alignment_strategy: 'line' )[:alignment_strategy]).to eq AlignLine
        end

        it 'sets an error if the requested alignment strategy is not known, or not provided' do
          flags   = ParseArgs.call([])
          options = InterpretFlags.new(flags.merge(alignment_strategy: 'chunk'), stdin, stdout)
          expect(options.errors.join).to_not include 'alignment-strategy'

          options = InterpretFlags.new(flags.merge(alignment_strategy: 'nonsense'), stdin, stdout)
          expect(options.errors.join).to include 'alignment-strategy does not know'

          options = InterpretFlags.new(flags.merge(alignment_strategy: nil), stdin, stdout)
          expect(options.errors.join).to include 'alignment-strategy expected an alignment strategy'
        end

        it 'sets the debugger to the toplevel debugger' do
          options = InterpretFlags.new(ParseArgs.call([]), stdin, stdout)
          expect(options.annotator_options[:debugger]).to equal options.debugger
        end

        # TODO: markers
        it 'sets max_line_length to the max_line_length' do
          expect(call(max_line_length: 123321)[:max_line_length]).to eq 123321
        end

        it 'sets max_result_length to the max_result_length' do
          expect(call(max_result_length: 99889)[:max_result_length]).to eq 99889
        end
      end

      it 'has a fancy inspect that shows predicates and attributes on multiple lines' do
        inspected = call.inspect
        expect(inspected).to include "PREDICATES"
        expect(inspected).to include "ATTRIBUTES"
        expect(inspected.lines.size).to be > 1
        inspected.lines.each do |line|
          expect(line.size).to be < 80 # truncate output so it doesn't get spammy
        end
      end
    end
  end
end
