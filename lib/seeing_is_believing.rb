require 'tmpdir'

require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/annotate'
require 'seeing_is_believing/hash_struct'
require 'seeing_is_believing/evaluate_by_moving_files'

class SeeingIsBelieving
  class Options < HashStruct
    attribute(:filename)          { nil }
    attribute(:encoding)          { nil }
    attribute(:stdin)             { "" }
    attribute(:require)           { ['seeing_is_believing/the_matrix'] } # TODO: should rename to requires ?
    attribute(:load_path)         { [File.expand_path('..', __FILE__)] } # TODO: should rename to load_path_dirs ?
    attribute(:timeout_seconds)   { 0 }
    attribute(:debugger)          { Debugger::Null }
    attribute(:max_line_captures) { Float::INFINITY }
    attribute(:annotate)          { Annotate } # TODO: this is something like...
                                               # wrap_expressions   (but that conflicts with the WrapExpressions class)
                                               # record_expressions (kinda like this, wrapping expressions is generic, we are specifically wrapping them in recording code)
                                               # we output it to debugging as "TRANSLATED PROGRAM"
  end

  def self.call(*args)
    new(*args).call
  end

  attr_reader :options
  def initialize(program, options={})
    @program = program
    @program += "\n" unless @program.end_with? "\n"
    @options = Options.new options
  end

  def call
    @memoized_result ||= Dir.mktmpdir("seeing_is_believing_temp_dir") { |dir|
      options.filename ||= File.join(dir, 'program.rb')
      new_program = options.annotate.call @program,
                                          options.filename,
                                          options.max_line_captures

      options.debugger.context("TRANSLATED PROGRAM") { new_program }

      result = Result.new
      EvaluateByMovingFiles.call \
        new_program,
        options.filename,
        event_handler:   lambda { |event| EventStream::UpdateResult.call result, event },
        provided_input:  options.stdin,
        require:         options.require,
        load_path:       options.load_path,
        encoding:        options.encoding,
        timeout_seconds: options.timeout_seconds,
        debugger:        options.debugger

      options.debugger.context("RESULT") { result.inspect }

      result
    }
  end
end
