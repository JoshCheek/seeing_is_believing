# encoding: utf-8

require 'seeing_is_believing/version' # We print the version in the output
require 'seeing_is_believing/strict_hash'

class SeeingIsBelieving
  module Binary
    class ParseArgs
      class ParsedArgs < StrictHash
        attribute(:as)                    { nil }
        attribute(:help)                  { nil }
        attribute(:encoding)              { nil }
        attribute(:debug)                 { false }
        attribute(:version)               { false }
        attribute(:clean)                 { false }
        attribute(:xmpfilter_style)       { false }
        attribute(:inherit_exit_status)   { false }
        attribute(:program_from_args)     { nil }
        attribute(:filename)              { nil }
        attribute(:max_line_length)       { Float::INFINITY }
        attribute(:max_result_length)     { Float::INFINITY }
        attribute(:max_captures_per_line) { Float::INFINITY }
        attribute(:timeout_seconds)       { 0 }
        attribute(:result_as_json)        { false }
        attribute(:deprecated_args)       { [] }
        attribute(:filenames)             { [] }
        attribute(:errors)                { [] }
        attribute(:require)               { ['seeing_is_believing/the_matrix'] }
        attribute(:load_path)             { [] }
        attribute(:alignment_strategy)    { 'chunk' }
        attribute(:markers)               { ParseArgs::Markers.new }
        attribute(:marker_regexes)        { ParseArgs::MarkerRegexes.new }
        attribute(:short_help_screen)     { ParseArgs.help_screen(false) }
        attribute(:long_help_screen)      { ParseArgs.help_screen(true) }
      end

      class Markers < StrictHash
        attributes value:     '# => '.freeze,
                   exception: '# ~> '.freeze,
                   stdout:    '# >> '.freeze,
                   stderr:    '# !> '.freeze
      end

      class MarkerRegexes < StrictHash
        attributes value:     '^#\s*=>\s*'.freeze,
                   exception: '^#\s*~>\s*'.freeze,
                   stdout:    '^#\s*>>\s*'.freeze,
                   stderr:    '^#\s*!>\s*'.freeze
      end

      class DeprecatedArg < StrictHash
        attributes :args, :explanation
        def to_s
          "Deprecated: `#{args.join ' '}` #{explanation}"
        end
      end



      # TODO: --cd dir | --cd :file:
      #   when given a dir, cd to that dir before executing the code
      #   when not given a dir, cd to the dir of the file being executed before executing it

      # TODO: --only-show-lines
      #   Output only on specified lines (doesn't change stdout/stderr/exceptions)

      # TODO: --alignment-strategy n-or-line / n-or-chunk / n-or-file (help-file should prob just link to cuke examples)
      # add default to number of captures (1000), require user to explicitly set it to infinity

      def self.call(args)
        new(args).call
      end

      def initialize(args)
        self.args = args.dup
      end

      def call
        @result ||= begin
          until args.empty?
            case (arg = args.shift)
            when '-h',  '--help'                  then flags[:help]                = 'help'
            when '-h+', '--help+'                 then flags[:help]                = 'help+'
            when '-c',  '--clean'                 then flags[:clean]               = true
            when '-v',  '--version'               then flags[:version]             = true
            when '-x',  '--xmpfilter-style'       then flags[:xmpfilter_style]     = true
            when '-i',  '--inherit-exit-status'   then flags[:inherit_exit_status] = true
            when '-j',  '--json'                  then flags[:result_as_json]      = true
            when '-g',  '--debug'                 then flags[:debug]               = true
            when '-d',  '--line-length'           then extract_positive_int_for :max_line_length,       arg
            when '-D',  '--result-length'         then extract_positive_int_for :max_result_length,     arg
            when '-n',  '--max-captures-per-line' then extract_positive_int_for :max_captures_per_line, arg
            when        '--number-of-captures'    then extracted = extract_positive_int_for :max_captures_per_line, arg
                                                       saw_deprecated "use --max-captures-per-line instead", arg, extracted
            when '-t',  '--timeout-seconds'       then extract_non_negative_float_for :timeout_seconds, arg
            when        '--timeout'               then extracted = extract_non_negative_float_for :timeout_seconds, arg
                                                       saw_deprecated "use --timeout-seconds instead", arg, extracted
            when '-r',  '--require'               then next_arg("#{arg} expected a filename as the following argument but did not see one")  { |filename|   flags[:require]           << filename }
            when '-I',  '--load-path'             then next_arg("#{arg} expected a directory as the following argument but did not see one") { |dir|        flags[:load_path]         << dir }
            when '-e',  '--program'               then next_arg("#{arg} expected a program as the following argument but did not see one")   { |program|    flags[:program_from_args] =  program }
            when '-a',  '--as'                    then next_arg("#{arg} expected a filename as the following argument but did not see one")  { |filename|   flags[:as]                =  filename }
            when '-s',  '--alignment-strategy'    then flags[:alignment_strategy] = args.shift
            when /\A-K(.+)/                       then flags[:encoding] = $1
            when '-K', '--encoding'               then next_arg("#{arg} expects an encoding, see `man ruby` for possibile values") { |encoding| flags[:encoding] = encoding }
            when        '--shebang'               then next_arg("#{arg} expected an arg: path to a ruby executable") { |executable| saw_deprecated "SiB now uses the Ruby it was invoked with", arg, executable }
            when /^(-.|--.*)$/                    then flags[:errors] << "Unknown option: #{arg.inspect}" # unknown flags
            when /^-[^-]/                         then args.unshift *normalize_shortflags(arg)
            else
              flags[:filenames] << arg
              flags[:filename] = arg
            end
          end
          flags
        end
      end

      private

      attr_accessor :args

      def flags
        @flags ||= ParsedArgs.new
      end

      def saw_deprecated(explanation, *args)
        flags[:deprecated_args] << DeprecatedArg.new(explanation: explanation, args: args)
      end

      def normalize_shortflags(consolidated_shortflag)
        shortflags = consolidated_shortflag[1..-1].chars.to_a # to_a for 1.9.3 -.-
        plusidx    = shortflags.index('+') || 0
        if 0 < plusidx
          shortflags[plusidx-1] << '+'
          shortflags.delete_at plusidx
        end
        shortflags.map { |flag| "-#{flag}" }
      end

      def next_arg(error_message, &success_block)
        arg = args.shift
        arg ? success_block.call(arg) : (flags[:errors] << error_message)
      end

      def extract_positive_int_for(key, flag)
        string = args.shift
        int    = string.to_i
        if int.to_s == string && 0 < int
          flags[key] = int
        else
          flags[:errors] << "#{flag} expects a positive integer argument"
        end
        string
      end

      def extract_non_negative_float_for(key, flag)
        string = args.shift
        float  = Float string
        raise if float < 0
        flags[key] = float
        string
      rescue
        flags[:errors] << "#{flag} expects a positive float or integer argument"
      end
    end

    def ParseArgs.help_screen(include_examples, markers=ParseArgs::Markers.new)
      value_marker     = markers.fetch(:value)
      exception_marker = markers.fetch(:exception)
      stdout_marker    = markers.fetch(:stdout)
      stderr_marker    = markers.fetch(:stderr)

<<FLAGS + if include_examples then <<EXAMPLES else '' end
Usage: seeing_is_believing [options] [filename]

  seeing_is_believing is a program and library that will evaluate a Ruby file and capture/display the results.

  If no filename is provided, the binary will read the program from standard input.

  -d,  --line-length n           # max length of the entire line (only truncates results, not source lines)
  -D,  --result-length n         # max length of the portion after the "#{value_marker}"
  -n,  --max-captures-per-line n # how many results to capture for a given line
                                   if you had 1 million results on a line, it could take a long time to record
                                   and serialize them, you might limit it to 1000 results as an optimization
  -s,  --alignment-strategy name # select the alignment strategy:
                                   chunk (DEFAULT) =>  each chunk of code is at the same alignment
                                   file            =>  the entire file is at the same alignment
                                   line            =>  each line is at its own alignment
  -t,  --timeout-seconds s       # how long to evaluate the source file before timing out
                                   0 means it will never timeout (this is the default)
                                   accepts floating point values (e.g. 0.5 would timeout after half a second)
  -I,  --load-path dir           # a dir that should be added to the $LOAD_PATH
  -r,  --require file            # additional files to be required before running the program
  -e,  --program program         # pass the program to execute as an argument
  -K,  --encoding encoding       # sets file encoding, equivalent to Ruby's -Kx (see `man ruby` for valid values)
  -a,  --as filename             # run the program as if it was the specified filename
  -c,  --clean                   # remove annotations from previous runs of seeing_is_believing
  -g,  --debug                   # print debugging information (useful if program is fucking up, or to better understand what SiB does)
  -x,  --xmpfilter-style         # annotate marked lines instead of every line
  -j,  --json                    # print results in json format (i.e. so another program can consume them)
  -i,  --inherit-exit-status     # exit with the exit status of the program being evaluated
       --shebang ruby-executable # if you want SiB to use some ruby other than the one in the path
  -v,  --version                 # print the version (#{VERSION})
  -h,  --help                    # help screen without examples
  -h+, --help+                   # help screen with examples
FLAGS

Examples: A few examples, for a more comprehensive set of examples, check out features/flags.feature

  Run the file f.rb
    $ echo __FILE__ > f.rb; seeing_is_believing f.rb
    __FILE__  #{value_marker}"f.rb"

  Aligning comments
    $ ruby -e 'puts "123\\n4\\n\\n567890"' > f.rb


    $ seeing_is_believing f.rb -s line
    123  #{value_marker}123
    4  #{value_marker}4

    567890  #{value_marker}567890


    $ seeing_is_believing f.rb -s chunk
    123  #{value_marker}123
    4    #{value_marker}4

    567890  #{value_marker}567890


    $ seeing_is_believing f.rb -s file
    123     #{value_marker}123
    4       #{value_marker}4

    567890  #{value_marker}567890

  Run against standard input
    $ echo '3.times { |i| puts i }' | seeing_is_believing
    2.times { |i| puts i }  #{value_marker}2

    #{stdout_marker}0
    #{stdout_marker}1

  Run against a library you're working on by fixing the load path
    $ seeing_is_believing -I lib f.rb

  Load up some library (can be used in tandem with -I)
    $ seeing_is_believing -r pp -e 'pp [[*1..15],[*15..30]]; nil'
    pp [[*1..15],[*15..30]]; nil  #{value_marker}nil

    #{stdout_marker}[[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    #{stdout_marker} [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]]

  Only update the lines you've marked
    $ ruby -e 'puts "1\\n2 # =>\\n3"' | seeing_is_believing -x
    1
    2 #{value_marker}2
    3

  Set a timeout (especially useful if running via an editor)
    $ seeing_is_believing -e 'loop { sleep 1 }' -t 3.5
    Timeout Error after 3.5 seconds!

  Set the encoding to utf-8
    $ seeing_is_believing -Ku -e '"⛄ "'
    "⛄ "  #{value_marker}"⛄ "

  The exit status will be 1 if the error is displayable inline
    $ seeing_is_believing -e 'raise "omg"'; echo $?
    raise "omg"  #{exception_marker}RuntimeError: omg
    1

  The exit status will be 2 if the error is not displayable
    $ seeing_is_believing -e 'a='; echo $status
    -:1: syntax error, unexpected $end
    2

  Run with previous output
    $ echo "1+1  #{value_marker}old-value" | seeing_is_believing
    1+1  #{value_marker}2

    $ echo "1+1  #{value_marker}old-value" | seeing_is_believing --clean
    1+1

  If your Ruby binary is named something else (e.g. ruby2.0)
    $ ruby2.0 -S seeing_is_believing --shebang ruby2.0 -e '123'
    123  #{value_marker}123
EXAMPLES
    end
  end
end
