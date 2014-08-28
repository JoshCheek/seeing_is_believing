require 'eval_in'

class SeeingIsBelieving
  class EvaluateWithEvalIn
    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :filename, :input_stream, :matrix_filename, :require_flags, :load_path_flags, :encoding, :timeout, :ruby_executable, :debugger

    def initialize(program, filename, options={})
      self.program      = program
      # self.input_stream = options.fetch :input_stream, StringIO.new('')
      # self.timeout      = options[:timeout]
      # self.debugger     = options.fetch :debugger, Debugger.new(stream: nil)
    end

    def call
      eval_in_result = ::EvalIn.call(program, language: 'ruby/mri-2.1')
      Result.from_primitive(JSON.load eval_in_result.output)
    end
  end
end
