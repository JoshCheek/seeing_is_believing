require 'stringio'
require 'tmpdir'
require 'timeout'

require 'seeing_is_believing/queue'
require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/remove_inline_comments'
require 'seeing_is_believing/evaluate_by_moving_files'
require 'seeing_is_believing/wrap_expressions'

# might not work on windows b/c of assumptions about line ends
class SeeingIsBelieving
  BLANK_REGEX = /\A\s*\Z/

  def self.call(*args)
    new(*args).call
  end

  def initialize(program, options={})
    @program         = program
    @matrix_filename = options[:matrix_filename]
    @filename        = options[:filename]
    @stdin           = to_stream options.fetch(:stdin, '')
    @require         = options.fetch :require, []
    @load_path       = options.fetch :load_path, []
    @encoding        = options.fetch :encoding, nil
    @timeout         = options[:timeout]
    @debugger        = options.fetch :debugger, Debugger.new(enabled: false)
  end

  def call
    @memoized_result ||= begin
      # must use newline after code, or comments will comment out rescue section
      wrapped = WrapExpressions.call "#@program\n",
                                     before_all:  "begin;",
                                     after_all:   "\n"\
                                                  "rescue Exception;"\
                                                    "line_number = $!.backtrace.grep(/\#{__FILE__}/).first[/:\\d+/][1..-1].to_i;"\
                                                    "$seeing_is_believing_current_result.record_exception line_number, $!;"\
                                                    "$seeing_is_believing_current_result.exitstatus = 1;"\
                                                    "$seeing_is_believing_current_result.exitstatus = $!.status if $!.kind_of? SystemExit;"\
                                                  "end",
                                     before_each: -> line_number { "($seeing_is_believing_current_result.record_result(#{line_number}, (" },
                                     after_each:  -> line_number { ")))" }
      debugger.context("TRANSLATED PROGRAM") { wrapped }
      result = result_for wrapped
      debugger.context("RESULT") { result.inspect }
      result
    end
  end


  private

  attr_reader :matrix_filename, :debugger

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end

  def result_for(program)
    Dir.mktmpdir "seeing_is_believing_temp_dir" do |dir|
      filename = @filename || File.join(dir, 'program.rb')
      EvaluateByMovingFiles.new(program,
                                filename,
                                input_stream:    @stdin,
                                matrix_filename: matrix_filename,
                                require:         @require,
                                load_path:       @load_path,
                                encoding:        @encoding,
                                timeout:         @timeout)
                           .call
    end
  end
end
