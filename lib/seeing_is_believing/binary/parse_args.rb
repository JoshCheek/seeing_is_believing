# encoding: utf-8

require 'stringio'
require 'seeing_is_believing/version'
require 'seeing_is_believing/binary'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/binary/align_file'
require 'seeing_is_believing/binary/align_line'
require 'seeing_is_believing/binary/align_chunk'

class SeeingIsBelieving
  class Binary
    class ParseArgs
      def self.call(args, outstream)
        new(args, outstream).call
      end

      def initialize(args, outstream)
        self.args      = args
        self.filenames = []
        self.outstream = outstream
      end

      def call
        @result ||= begin
          until args.empty?
            case (arg = args.shift)
            when '-h',  '--help'                then options[:help]                = self.class.help_screen(false)
            when '-h+', '--help+'               then options[:help]                = self.class.help_screen(true)
            when '-c',  '--clean'               then options[:clean]               = true
            when '-v',  '--version'             then options[:version]             = true
            when '-x',  '--xmpfilter-style'     then options[:xmpfilter_style]     = true
            when '-i',  '--inherit-exit-status' then options[:inherit_exit_status] = true
            when '-j',  '--json'                then options[:result_as_json]      = true
            when '-g',  '--debug'               then options[:debugger]            = Debugger.new(stream: outstream, colour: true)
            when '-l',  '--start-line'          then extract_positive_int_for :start_line,         arg
            when '-L',  '--end-line'            then extract_positive_int_for :end_line,           arg
            when '-d',  '--line-length'         then extract_positive_int_for :max_line_length,    arg
            when '-D',  '--result-length'       then extract_positive_int_for :max_result_length,  arg
            when '-n',  '--number-of-captures'  then extract_positive_int_for :number_of_captures, arg
            when '-t',  '--timeout'             then extract_non_negative_float_for :timeout,      arg
            when '-r',  '--require'             then next_arg("#{arg} expected a filename as the following argument but did not see one")       { |filename|   options[:require]   << filename }
            when '-I',  '--load-path'           then next_arg("#{arg} expected a directory as the following argument but did not see one")      { |dir|        options[:load_path] << dir }
            when '-e',  '--program'             then next_arg("#{arg} expected a program as the following argument but did not see one")        { |program|    options[:program]   =  program }
            when '-a',  '--as'                  then next_arg("#{arg} expected a filename as the following argument but did not see one")       { |filename|   options[:as]        =  filename }
            when        '--shebang'             then next_arg("#{arg} expects a ruby executable as the following argument but did not see one") { |executable| options[:shebang]   =  executable }
            when '-s',  '--alignment-strategy'  then extract_alignment_strategy
            when /\A-K(.+)/                    then options[:encoding] = $1
            when '-K', '--encoding'            then next_arg("#{arg} expects an encoding, see `man ruby` for possibile values") { |encoding| options[:encoding] = encoding }
            when /^-/                          then options[:errors] << "Unknown option: #{arg.inspect}" # unknown flags
            else
              filenames << arg
              options[:filename] = arg
            end
          end
          normalize_and_validate
          options
        end
      end

      private

      attr_accessor :filenames, :args, :outstream


      def normalize_and_validate
        if 1 < filenames.size
          options[:errors] << "Can only have one filename, but had: #{filenames.map(&:inspect).join ', '}"
        elsif filenames.any? && options[:program]
          options[:errors] << "You passed the program in an argument, but have also specified the filename #{filenames.first.inspect}"
        end

        if options[:end_line] < options[:start_line]
          options[:start_line], options[:end_line] = options[:end_line], options[:start_line]
        end
      end

      def options
        @options ||= {
          debugger:            Debugger.new(stream: nil),
          version:             false,
          clean:               false,
          xmpfilter_style:     false,
          inherit_exit_status: false,
          program:             nil,
          filename:            nil,
          start_line:          1,
          end_line:            Float::INFINITY,
          max_line_length:     Float::INFINITY,
          max_result_length:   Float::INFINITY,
          number_of_captures:  Float::INFINITY,
          timeout:             0, # timeout lib treats this as infinity
          errors:              [],
          require:             [],
          load_path:           [],
          alignment_strategy:  AlignChunk,
          shebang:             'ruby',
          result_as_json:      false,
        }
      end


      def extract_alignment_strategy
        strategies = {
          'file'  => AlignFile,
          'chunk' => AlignChunk,
          'line'  => AlignLine,
        }
        next_arg "alignment-strategy expected an alignment strategy as the following argument but did not see one" do |strategy_name|
          if strategies[strategy_name]
            options[:alignment_strategy] = strategies[strategy_name]
          else
            options[:errors] << "alignment-strategy does not know #{strategy_name}, only knows: #{strategies.keys.join(', ')}"
          end
        end
      end

      def next_arg(error_message, &success_block)
        arg = args.shift
        arg ? success_block.call(arg) : (options[:errors] << error_message)
      end

      def extract_positive_int_for(key, flag)
        string = args.shift
        int    = string.to_i
        if int.to_s == string && 0 < int
          options[key] = int
        else
          options[:errors] << "#{flag} expects a positive integer argument"
        end
      end

      def extract_non_negative_float_for(key, flag)
        float = Float args.shift
        raise if float < 0
        options[key] = float
      rescue
        options[:errors] << "#{flag} expects a positive float or integer argument"
      end

    end

    def ParseArgs.help_screen(include_examples)
<<FLAGS + if include_examples then <<EXAMPLES else '' end
Usage: seeing_is_believing [options] [filename]

  seeing_is_believing is a program and library that will evaluate a Ruby file and capture/display the results.

  If no filename is provided, the binary will read the program from standard input.

  -l,  --start-line n            # line number to begin showing results on
  -L,  --end-line n              # line number to stop showing results on
  -d,  --line-length n           # max length of the entire line (only truncates results, not source lines)
  -D,  --result-length n         # max length of the portion after the "#{VALUE_MARKER}"
  -n,  --number-of-captures n    # how many results to capture for a given line
                                   if you had 1 million results on a line, it could take a long time to record
                                   and serialize them, you might limit it to 1000 results as an optimization
  -s,  --alignment-strategy name # select the alignment strategy:
                                   chunk (DEFAULT) =>  each chunk of code is at the same alignment
                                   file            =>  the entire file is at the same alignment
                                   line            =>  each line is at its own alignment
  -t,  --timeout n               # timeout limit in seconds when evaluating source file (ex. -t 0.3 or -t 3)
  -I,  --load-path dir           # a dir that should be added to the $LOAD_PATH
  -r,  --require file            # additional files to be required before running the program
  -e,  --program program         # Pass the program to execute as an argument
  -K,  --encoding encoding       # sets file encoding, equivalent to Ruby's -Kx (see `man ruby` for valid values)
  -a,  --as filename             # run the program as if it was the specified filename
  -c,  --clean                   # remove annotations from previous runs of seeing_is_believing
  -g,  --debug                   # print debugging information (useful if program is fucking up, or if you want to brag)
  -x,  --xmpfilter-style         # annotate marked lines instead of every line
  -j,  --json                    # print results in json format (i.e. so another program can consume them)
  -i,  --inherit-exit-status     # exit with the exit status of the program being eval
       --shebang ruby-executable # if you want SiB to use some ruby other than the one in the path
  -v,  --version                 # print the version (#{VERSION})
  -h,  --help                    # help screen without examples
  -h+, --help+                   # help screen with examples
FLAGS

Examples: A few examples, for a more comprehensive set of examples, check out features/flags.feature

  Run the file f.rb
    $ echo __FILE__ > f.rb; seeing_is_believing f.rb
    __FILE__  #{VALUE_MARKER}"f.rb"

  Aligning comments
    $ ruby -e 'puts "123\\n4\\n\\n567890"' > f.rb


    $ seeing_is_believing f.rb -s line
    123  #{VALUE_MARKER}123
    4  #{VALUE_MARKER}4

    567890  #{VALUE_MARKER}567890


    $ seeing_is_believing f.rb -s chunk
    123  #{VALUE_MARKER}123
    4    #{VALUE_MARKER}4

    567890  #{VALUE_MARKER}567890


    $ seeing_is_believing f.rb -s file
    123     #{VALUE_MARKER}123
    4       #{VALUE_MARKER}4

    567890  #{VALUE_MARKER}567890

  Run against standard input
    $ echo '3.times { |i| puts i }' | seeing_is_believing
    2.times { |i| puts i }  #{VALUE_MARKER}2

    #{STDOUT_MARKER}0
    #{STDOUT_MARKER}1

  Run against a library you're working on by fixing the load path
    $ seeing_is_believing -I lib f.rb

  Load up some library (can be used in tandem with -I)
    $ seeing_is_believing -r pp -e 'pp [[*1..15],[*15..30]]; nil'
    pp [[*1..15],[*15..30]]; nil  #{VALUE_MARKER}nil

    #{STDOUT_MARKER}[[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    #{STDOUT_MARKER} [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]]

  Only update the lines you've marked
    $ ruby -e 'puts "1\\n2 # =>\\n3"' | seeing_is_believing -x
    1
    2 #{VALUE_MARKER}2
    3

  Set a timeout (especially useful if running via an editor)
    $ seeing_is_believing -e 'loop { sleep 1 }' -t 3
    Timeout Error after 3.0 seconds!

  Set the encoding to utf-8
    $ seeing_is_believing -Ku -e '"⛄ "'
    "⛄ "  #{VALUE_MARKER}"⛄ "

  The exit status will be 1 if the error is displayable inline
    $ seeing_is_believing -e 'raise "omg"'; echo $?
    raise "omg"  #{EXCEPTION_MARKER}RuntimeError: omg
    1

  The exit status will be 2 if the error is not displayable
    $ seeing_is_believing -e 'a='; echo $status
    -:1: syntax error, unexpected $end
    2

  Run with previous output
    $ echo "1+1  #{VALUE_MARKER}old-value" | seeing_is_believing
    1+1  #{VALUE_MARKER}2

    $ echo "1+1  #{VALUE_MARKER}old-value" | seeing_is_believing --clean
    1+1

  If your Ruby binary is named something else (e.g. ruby2.0)
    $ ruby2.0 -S seeing_is_believing --shebang ruby2.0 -e '123'
    123  #{VALUE_MARKER}123
EXAMPLES
    end
  end
end
