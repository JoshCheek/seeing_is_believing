require 'stringio'
require 'tmpdir'
require 'timeout'

require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/evaluate_by_moving_files'
require 'seeing_is_believing/wrap_expressions'

class SeeingIsBelieving
  BLANK_REGEX = /\A\s*\Z/

  def self.call(*args)
    new(*args).call
  end

  def initialize(program, options={})
    @program                    = program
    @matrix_filename            = options.fetch :matrix_filename, 'seeing_is_believing/the_matrix' # how to hijack the env
    @filename                   = options[:filename]
    @stdin                      = to_stream options.fetch(:stdin, '')
    @require                    = options.fetch :require,   []
    @load_path                  = options.fetch :load_path, []
    @encoding                   = options.fetch :encoding,  nil
    @timeout                    = options[:timeout]
    @debugger                   = options.fetch :debugger, Debugger.new(stream: nil)
    @ruby_executable            = options.fetch :ruby_executable, 'ruby'
    @number_of_captures         = options.fetch :number_of_captures, Float::INFINITY

    @wrap_expressions_callbacks = {}
    @wrap_expressions_callbacks[:before_all]  = options.fetch :before_all,  -> { "begin; $SiB.max_line_captures = #{number_of_captures_as_str}; $SiB.num_lines = #{program.lines.size}; " }
    @wrap_expressions_callbacks[:after_all]   = options.fetch :after_all,   -> { ";rescue Exception;"\
                                                                                   "lambda {"\
                                                                                     "line_number = $!.backtrace.grep(/\#{__FILE__}/).first[/:\\d+/][1..-1].to_i;"\
                                                                                     "$SiB.record_exception line_number, $!;"\
                                                                                     "$SiB.exitstatus = 1;"\
                                                                                     "$SiB.exitstatus = $!.status if $!.kind_of? SystemExit;"\
                                                                                   "}.call;"\
                                                                                 "end"
                                                                            }
    @wrap_expressions_callbacks[:before_each] = options.fetch :before_each, -> line_number { "(" }
    @wrap_expressions_callbacks[:after_each]  = options.fetch :after_each,  -> line_number { ").tap { |v| $SiB.record_result(:inspect, #{line_number}, v) }" }
  end

  def call
    @memoized_result ||= begin
      new_program = program_that_will_record_expressions
      debugger.context("TRANSLATED PROGRAM") { new_program }
      result = result_for new_program
      debugger.context("RESULT") { result.inspect }
      result
    end
  end

  private

  attr_reader :debugger

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end

  def program_that_will_record_expressions
    WrapExpressions.call "#{@program}\n", @wrap_expressions_callbacks
  end

  def result_for(program)
    Dir.mktmpdir "seeing_is_believing_temp_dir" do |dir|
      filename = @filename || File.join(dir, 'program.rb')
      EvaluateByMovingFiles.call program,
                                 filename,
                                 input_stream:       @stdin,
                                 matrix_filename:    @matrix_filename,
                                 require:            @require,
                                 load_path:          @load_path,
                                 encoding:           @encoding,
                                 timeout:            @timeout,
                                 ruby_executable:    @ruby_executable,
                                 debugger:           @debugger
    end
  end

  def number_of_captures_as_str
    return 'Float::INFINITY' if @number_of_captures == Float::INFINITY
    @number_of_captures.inspect
  end
end
