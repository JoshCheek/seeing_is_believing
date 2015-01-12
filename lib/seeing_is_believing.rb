require 'tmpdir'

require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/annotate'
require 'seeing_is_believing/evaluate_by_moving_files'

class SeeingIsBelieving
  BLANK_REGEX = /\A\s*\Z/

  def self.call(*args)
    new(*args).call
  end

  def initialize(program, options={})
    options            = options.dup
    @program           = program
    @stdin             = options.delete(:stdin)                 || '' # can also be a stream
    @timeout_seconds   = options.delete(:timeout_seconds)       || 0
    @load_path         = options.delete(:load_path)             || []
    @encoding          = options.delete(:encoding)              || nil
    @filename          = options.delete(:filename)              || nil
    @require           = options.delete(:require)               || ['seeing_is_believing/the_matrix']
    @debugger          = options.delete(:debugger)              || Debugger.new(stream: nil)
    @max_line_captures = options.delete(:max_line_captures) || Float::INFINITY
    @evaluator         = options.delete(:evaluator)             || EvaluateByMovingFiles
    @annotate          = options.delete(:annotate)              || Annotate
    options.any? && raise(ArgumentError, "Unknown options: #{options.inspect}")
  end

  def call
    @memoized_result ||= Dir.mktmpdir("seeing_is_believing_temp_dir") { |dir|
      filename    = @filename || File.join(dir, 'program.rb')
      new_program = @annotate.call "#{@program.chomp}\n", filename, @max_line_captures
      @debugger.context("TRANSLATED PROGRAM") { new_program }

      result = Result.new
      @evaluator.call new_program,
                      filename,
                      event_handler:   lambda { |event| EventStream::UpdateResult.call result, event },
                      provided_input:  @stdin,
                      require:         @require,
                      load_path:       @load_path,
                      encoding:        @encoding,
                      timeout_seconds: @timeout_seconds,
                      debugger:        @debugger

      @debugger.context("RESULT") { result.inspect }

      result
    }
  end
end
