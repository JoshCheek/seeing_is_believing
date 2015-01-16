require 'tmpdir'

require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/rewrite_code'
require 'seeing_is_believing/hash_struct'
require 'seeing_is_believing/evaluate_by_moving_files'
require 'seeing_is_believing/event_stream/debugging_handler'
require 'seeing_is_believing/event_stream/update_result_handler'

class SeeingIsBelieving
  class Options < HashStruct
    predicate(:event_handler)     { EventStream::UpdateResultHandler.new Result.new }
    attribute(:filename)          { nil }
    attribute(:encoding)          { nil }
    attribute(:stdin)             { "" }
    attribute(:require_files)     { ['seeing_is_believing/the_matrix'] }
    attribute(:load_path_dirs)    { [File.expand_path('..', __FILE__)] }
    attribute(:timeout_seconds)   { 0 }
    attribute(:debugger)          { Debugger::Null }
    attribute(:max_line_captures) { Float::INFINITY }
    attribute(:rewrite_code)      { RewriteCode }
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
      new_program = options.rewrite_code.call @program,
                                              options.filename,
                                              options.max_line_captures

      event_handler = options.event_handler
      if options.debugger.enabled?
        options.debugger.context("REWRITTEN PROGRAM") { new_program }
        event_handler = EventStream::DebuggingHandler.new options.debugger, event_handler
      end

      EvaluateByMovingFiles.call \
        new_program,
        options.filename,
        event_handler:   event_handler,
        provided_input:  options.stdin,
        require_files:   options.require_files,
        load_path_dirs:  options.load_path_dirs,
        encoding:        options.encoding,
        timeout_seconds: options.timeout_seconds

      event_handler.return_value
    }
  end
end
