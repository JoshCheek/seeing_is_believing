require 'seeing_is_believing/binary/interpret_flags'

RSpec.describe 'SeeingIsBelieving::Binary::InterpretFlags' do
  desribt 'annotator' do
    it 'annotates every line by default'
    it 'annotates xmpfilter-style if xmpfilter_style was set'
  end

  describe 'help' do
    context 'when the value is "help"' do
      it 'sets print_help?'
      it 'sets the help_screen to the short one'
    end

    context 'when the value is "help+"' do
      it 'sets print_help?'
      it 'sets the help screen to the long one'
    end
  end

  context 'debug' do
    it 'sts a null debugger when false'
    it 'sets a debugger to the output stream when true'
  end

  context 'markers' do
    # TODO: fix this later to use objs
  end

  context 'timeout' do
    it 'sets timeout to the value'
  end

  context 'shebang' do
    it 'sets shebang to the value'
  end

  context 'filename' do
    it 'sets this as the filename'
  end

  context 'filenames' do
    it 'sets an error if there are too many filenames'
    it 'sets an error if there is a filename and the program was also passed on stdin'
  end

  context 'predicates' do
    it 'sets print_version? when version is true'
    it 'sets inherit_exit_status when inherit_exit_status is true'
    it 'sets result_as_json when result_as_json is true'
    it 'sets print_help when help has a value'
    it 'sets print_cleaned when clean is set'
    it 'sets provided_filename_dne when there is a filename and that file does not exist'
    it 'sets sets file_is_on_stdin when there is no filename and the program is not provided in the args'
  end

  context 'body' do
    it 'is a default string if we\'re going to print the version or help instead of the program'
    it 'is the program_from_args if this is provided'
    it 'is stdin if there is no file and no program_from_args'
    it 'is the file body if the filename is provded and exists'
  end

  context 'prepared_body' do
    it 'is the body after being run throught he annotator\'s prepare method'
  end

  context 'lib_options' do
    specify 'evaluate_with is EvaluateByMovingFiles by default'
    specify 'evaluate_with is EvaluateWithEvalIn if safe is set'
    specify 'filename is the as option or the provided filename'
    specify 'ruby_executable is the shebang'
    specify 'stdin is empty when the program is on stdin, and is stdin otherwise'
    # TODO: Add cuke with required file printing
    specify 'require is the matrix plus any other required files'
    specify 'load_path is the load_path'
    # TODO: Default this to utf-8
    specify 'encoding is set to the encoding'
    specify 'timeout is set to timeout'
    specify 'debugger is the same as the toplevel debugger'
    specify 'number_of_captures is number_of_captures'
    specify 'record_expressions is the annotator\'s expression wrapper'
  end

  context 'annotator_options' do
    it 'sets alignment_strategy to the provided alignment strategy'
    it 'sets an error if the requested alignment strategy is not known'
    it 'sets an error no alignment strategy was provided'
    it 'sets the debugger to the toplevel debugger'
    # TODO: markers
    it 'sets max_line_length to the max_line_length'
    it 'sets max_result_length to the max_result_length'
  end

  context 'print_errors?' do
    it 'is true when there are errors'
  end

  context 'fetch' do
    it 'returns the requested key, when it has that attribute'
    it 'raises an error when the attribute doesn\'t exist'
  end

  context 'accessors' do
    specify 'they look up their value in the attributes array'
    specify 'they blow up when asked for an unknown attribute'
  end

  context 'predicates' do
    specify 'they reurn the predicate when it exists'
    specify 'they return nil when it doesn\'t exist'
  end
end
