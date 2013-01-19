require 'stringio'
require 'yaml'
require 'open3'

require 'seeing_is_believing/result'
require 'seeing_is_believing/expression_list'

# might not work on windows b/c of assumptions about line ends
class SeeingIsBelieving
  include TracksLineNumbersSeen

  def initialize(string_or_stream)
    @string = string_or_stream
    @stream = to_stream string_or_stream
  end

  def call
    @memoized_result ||= begin
      program = ''
      program << expression_list.call until stream.eof?
      result_for record_exceptions_in(program), min_line_number, max_line_number
    end
  end

  private

  attr_reader :stream

  def expression_list
    @expression_list ||= ExpressionList.new generator: lambda { stream.gets.chomp },
                                            on_complete: lambda { |line, children, completions, line_number|
                                              track_line_number line_number
                                              expression = [line, *children, *completions].map(&:chomp).join("\n")
                                              if expression =~ /\A\s*\Z/ || SyntaxAnalyzer.ends_in_comment?(expression) || SyntaxAnalyzer.will_return?(expression)
                                                expression + "\n"
                                              else
                                                record_yahself(expression, line_number) + "\n"
                                              end
                                            }
  end

  def to_stream(string_or_stream)
    return string_or_stream if string_or_stream.respond_to? :gets
    StringIO.new string_or_stream
  end

  def record_yahself(line, line_number)
    "($seeing_is_believing_current_result.record_result(#{line_number}, (#{line})))"
  end

  def record_exceptions_in(code)
    # must use newline after code, or comments will comment out rescue section
    "begin;"\
      "#{code}\n"\
    "rescue Exception;"\
      "line_number = $!.backtrace.first[/:\\d+:/][1..-2].to_i;"\
      "$seeing_is_believing_current_result.record_exception line_number, $!;"\
    "end"
  end

  def result_for(program, min_line_number, max_line_number)
    stdout, stderr, exitstatus = Open3.capture3('ruby', '-I', File.dirname(__FILE__),
                                                        '-r', 'seeing_is_believing/the_matrix',
                                                        stdin_data: program)
    raise "Exitstatus: #{exitstatus.inspect},\nError: #{stderr.inspect}" unless exitstatus.success?
    # should we raise here if there is an unsuccessful exitstatus?
    YAML.load(stdout).tap do |result|
      result.track_line_number min_line_number
      result.track_line_number max_line_number
    end
  rescue Exception
    $stderr.puts "It blew up. Not too surprising given that seeing_is_believing is pretty rough around the edges, but still this shouldn't happen."
    $stderr.puts "Please log an issue at: https://github.com/JoshCheek/seeing_is_believing/issues"
    $stderr.puts
    $stderr.puts "Program: #{program.inspect}"
    $stderr.puts
    $stderr.puts "Stdout: #{stdout.inspect}"
    $stderr.puts
    $stderr.puts "Stderr: #{stderr.inspect}"
    $stderr.puts
    $stdout.puts "Status: #{exitstatus.inspect}"
    raise $!
  end
end
