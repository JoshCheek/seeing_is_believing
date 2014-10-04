require 'stringio'
require 'tmpdir'

require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/inspect_expressions'
require 'seeing_is_believing/evaluate_by_moving_files'

class SeeingIsBelieving
  BLANK_REGEX = /\A\s*\Z/

  def self.call(*args)
    new(*args).call
  end

  def initialize(program, options={})
    @program            = program
    @filename           = options[:filename]
    @stdin              = to_stream options.fetch(:stdin, '')
    @require            = options.fetch :require, ['seeing_is_believing/the_matrix']
    @load_path          = options.fetch :load_path, []
    @encoding           = options.fetch :encoding,  nil
    @timeout            = options[:timeout]
    @debugger           = options.fetch :debugger, Debugger.new(stream: nil)
    @ruby_executable    = options.fetch :ruby_executable, 'ruby'
    @number_of_captures = options.fetch :number_of_captures, Float::INFINITY
    @evaluator          = options.fetch :evaluator, EvaluateByMovingFiles
    @record_expressions = options.fetch :record_expressions, InspectExpressions # TODO: rename to wrap_expressions
  end

  def call
    @memoized_result ||= Dir.mktmpdir("seeing_is_believing_temp_dir") { |dir|
      filename    = @filename || File.join(dir, 'program.rb')
      new_program = @record_expressions.call "#{@program.chomp}\n", filename, @number_of_captures
      @debugger.context("TRANSLATED PROGRAM") { new_program }

      result = @evaluator.call new_program,
                      filename,
                      input_stream:       @stdin,
                      require:            @require,
                      load_path:          @load_path,
                      encoding:           @encoding,
                      timeout:            @timeout,
                      ruby_executable:    @ruby_executable,
                      debugger:           @debugger

      @debugger.context("RESULT") { result.inspect }

      result
    }
  end

  private

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end
end
