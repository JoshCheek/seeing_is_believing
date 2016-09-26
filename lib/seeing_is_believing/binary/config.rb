# encoding: utf-8
require 'seeing_is_believing'
require 'seeing_is_believing/binary/data_structures'

# one of these will be the alignment strategy
require 'seeing_is_believing/binary/align_file'
require 'seeing_is_believing/binary/align_line'
require 'seeing_is_believing/binary/align_chunk'

# one of these will annotate the bdoy
require 'seeing_is_believing/binary/annotate_every_line'
require 'seeing_is_believing/binary/annotate_marked_lines'


class SeeingIsBelieving
  module Binary
    class Config < HashStruct
      DeprecatedArgMessage = Binary::ErrorMessage.for :args do
        def to_s
          "Deprecated: `#{args.join ' '}` #{explanation}"
        end
      end

      predicate(:print_version)         { false }
      predicate(:print_cleaned)         { false }
      predicate(:print_help)            { false }
      predicate(:print_event_stream)    { false }
      predicate(:result_as_json)        { false }
      predicate(:inherit_exitstatus)    { false }
      predicate(:remove_value_prefixes) { true  }
      predicate(:debug)                 { false }
      predicate(:ignore_unknown_flags)  { false }
      attribute(:body)                  { nil }
      attribute(:filename)              { nil }
      attribute(:errors)                { [] }
      attribute(:deprecations)          { [] }
      attribute(:timeout_seconds)       { 0 }
      attribute(:annotator)             { AnnotateEveryLine }
      attribute(:debugger)              { Debugger::Null }
      attribute(:markers)               { Markers.new }
      attribute(:help_screen)           { |c| Binary.help_screen c.markers }
      attribute(:lib_options)           { SeeingIsBelieving::Options.new }
      attribute(:annotator_options)     { AnnotatorOptions.new }

      def add_error(explanation)
        errors << ErrorMessage.new(explanation: explanation)
      end

      def parse_args(args)
        args          = args.dup
        as            = nil
        filenames     = []
        unknown_flags = []

        extract_positive_int_for = lambda do |flagname, &on_success|
          string = args.shift
          int    = string.to_i
          if int.to_s == string && 0 < int
            on_success.call int
          else
            add_error "#{flagname} expects a positive integer argument"
          end
          string
        end

        extract_non_negative_float_for = lambda do |flagname, &on_success|
          begin
            string = args.shift
            float  = Float string
            raise if float < 0
            on_success.call float
            string
          rescue
            add_error "#{flagname} expects a positive float or integer argument"
          end
        end

        saw_deprecated = lambda do |explanation, *args|
          self.deprecations << DeprecatedArgMessage.new(explanation: explanation, args: args)
        end

        next_arg = lambda do |flagname, argtype, &on_success|
          arg = args.shift
          arg ? on_success.call(arg) :
                add_error("#{flagname} needs an argument (#{argtype})")
          arg
        end

        until args.empty?
          case (arg = args.shift)
          when '-c', '--clean'
            self.print_cleaned = true

          when '-v', '--version'
            self.print_version = true

          when '--ignore-unknown-flags'
            self.ignore_unknown_flags = true

          when '-x', '--xmpfilter-style'
            self.annotator                 = AnnotateMarkedLines
            self.lib_options.rewrite_code  = AnnotateMarkedLines.code_rewriter(markers)
            self.remove_value_prefixes     = false
            self.lib_options.require_files << 'pp'

          when '-i', '--inherit-exitstatus', '--inherit-exit-status'
            self.inherit_exitstatus = true
            arg.include?("exit-status") &&
              saw_deprecated.call("Dash has been removed for consistency, use --inherit-exitstatus", arg)

          when '-j', '--json'
            self.result_as_json = true

          when '--stream'
            self.print_event_stream = true

          when '-h', '--help'
            self.print_help = true
            self.help_screen = Binary.help_screen(markers)

          when '-h+', '--help+'
            self.print_help  = true
            self.help_screen = Binary.help_screen_extended(markers)

          when '-g', '--debug'
            self.debug = true

          when '--debug-to'
            next_arg.call arg, "a filename" do |filename|
              self.debug = filename
            end

          when '-d', '--line-length'
            extract_positive_int_for.call arg do |n|
              self.annotator_options.max_line_length = n
            end

          when '-D', '--result-length'
            extract_positive_int_for.call arg do |n|
              self.annotator_options.max_result_length = n
            end

          when '-n', '--max-line-captures', '--number-of-captures'
            extracted = extract_positive_int_for.call arg do |n|
              self.lib_options.max_line_captures = n
            end
            seen = [arg]
            seen << extracted if extracted
            '--number-of-captures' == arg && saw_deprecated.call("use --max-line-captures instead", *seen)

          when '-t', '--timeout-seconds', '--timeout'
            extracted = extract_non_negative_float_for.call arg do |n|
              self.timeout_seconds             = n
              self.lib_options.timeout_seconds = n
            end
            '--timeout' == arg  && saw_deprecated.call("use --timeout-seconds instead", arg, extracted)

          when '-r', '--require'
            next_arg.call arg, "a filename" do |filename|
              self.lib_options.require_files << filename
            end

          when '-I', '--load-path'
            next_arg.call arg, "a directory" do |dir|
              self.lib_options.load_path_dirs << dir
            end

          when '-e', '--program'
            next_arg.call arg, "the program body" do |program|
              self.body = program
            end

          when '-a', '--as'
            next_arg.call arg, "a filename"  do |filename|
              as = filename
            end

          when '-s', '--alignment-strategy'
            strategies     = {'file' => AlignFile, 'chunk' => AlignChunk, 'line' => AlignLine}
            strategy_names = strategies.keys.inspect
            next_arg.call arg, "one of these alignment strategies: #{strategy_names}" do |name|
              if strategies[name]
                self.annotator_options.alignment_strategy = strategies[name]
              else
                add_error("#{arg} got the alignment strategy #{name.inspect}, expected one of: #{strategy_names}")
              end
            end

          when '--shebang'
            executable = args.shift
            if executable
              saw_deprecated.call "SiB now uses the Ruby it was invoked with", arg, executable
            else
              add_error("#{arg} expected an arg: path to a ruby executable")
              saw_deprecated.call "SiB now uses the Ruby it was invoked with", arg
            end

          when /\A-K(.+)/
            self.lib_options.encoding = $1

          when '-K', '--encoding'
            next_arg.call arg, "an encoding" do |encoding|
              self.lib_options.encoding = encoding
            end

          when /^(-.|--.*)$/
            unknown_flags << arg

          when /^-[^-]/
            args.unshift *arg.scan(/[^-]\+?/).map { |flag| "-#{flag}" }

          else
            filenames << arg
          end
        end

        unknown_flags.each do |flag|
          break if ignore_unknown_flags?
          add_error "#{flag} is not a flag, see the help screen (-h) for a list of options"
        end

        filenames.size > 1 &&
          add_error("can only have one filename but found #{filenames.map(&:inspect).join ', '}")

        result_as_json? && annotator == AnnotateMarkedLines &&
          add_error("SiB does not currently support output with both json and xmpfilter... maybe v4 :)")

        print_event_stream? && (result_as_json? || annotator == AnnotateMarkedLines) &&
          add_error("can only have one output format, --stream is not compatible with --json, -x, and --xmpfilter-style")

        self.filename                  = filenames.first
        self.lib_options.filename      = as || filename
        self.lib_options.debugger      = debugger
        self.annotator_options.markers = markers

        self
      end

      def finalize(stdin, stdout, stderr, file_class)
        if print_event_stream?
          require 'seeing_is_believing/event_stream/handlers/stream_json_events'
          lib_options.event_handler = EventStream::Handlers::StreamJsonEvents.new(stdout)
        end

        case debug
        when String
          debug_file    = File.open(debug, 'a').tap { |f| f.sync = true }
          self.debugger = Debugger.new stream: debug_file, colour: false
        when true
          self.debugger = Debugger.new stream: stderr, colour: stderr.tty?
        end
        self.lib_options.debugger = debugger

        if filename && body
          add_error("Cannot give a program body and a filename to get the program body from.")
        elsif filename && file_class.exist?(filename)
          self.lib_options.stdin = stdin
          self.body = file_class.read filename
        elsif filename
          add_error("#{filename} does not exist!")
        elsif body
          self.lib_options.stdin = stdin
        elsif print_version? || print_help? || errors.any?
          self.body = ""
        else
          self.body = stdin.read
        end

        self
      end

    end
  end

  def Binary.help_screen(markers)
    value  = markers[:value][:prefix]
    stdout = markers[:stdout][:prefix]

    <<FLAGS
Usage: seeing_is_believing [options] [filename]

  seeing_is_believing is a program and library that will evaluate a Ruby file and capture/display the results.

Notes:

  * If no filename or program (-e option) are provided, the program will read from standard input.
  * The process's stdin will be passed to the program unless the program body is on stdin.
  * The exit status will be:
    0 - No errors
    1 - Displayable error (e.g. code raises an exception while running)
    2 - Non-displayable error (e.g. a syntax error, a timeout)
    n - The program's exit status if the --inherit-exitstatus option is set

Options:
  -d,  --line-length n           # max length of the entire line (only truncates results, not source lines)
  -D,  --result-length n         # max length of the portion after the "#{value}"
  -n,  --max-line-captures n     # how many results to capture for a given line
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
  -e,  --program program-body    # pass the program body to execute as an argument
  -K,  --encoding encoding       # sets file encoding, equivalent to Ruby's -Kx (see `man ruby` for valid values)
  -a,  --as filename             # run the program as if it was the specified filename
  -c,  --clean                   # remove annotations from previous runs of seeing_is_believing
  -g,  --debug                   # print debugging information
  -x,  --xmpfilter-style         # annotate marked lines instead of every line
  -j,  --json                    # print results in json format (i.e. so another program can consume them)
  -i,  --inherit-exitstatus      # exit with the exit status of the program being evaluated
       --stream                  # a JSON stream of every event ias it is seen (such as recording a line)
       --ignore-unknown-flags    # don't error when flag is not in this list
                                   allows integrating code to support compatibility with future versions of SiB
  -v,  --version                 # print the version (#{VERSION})
  -h,  --help                    # help screen without examples
  -h+, --help+                   # help screen with examples
FLAGS
  end

  def Binary.help_screen_extended(markers)
    value  = markers[:value][:prefix]
    stdout = markers[:stdout][:prefix]
    help_screen(markers) << <<EXAMPLES
Examples: A few examples, for a more comprehensive set of examples, check out features/flags.feature
  NOTE: $'1\\n2' is the bash string literal for Ruby's "1\\n2"

  Run the file myfile.rb
    $ echo __FILE__ > myfile.rb; seeing_is_believing myfile.rb
    __FILE__  #{value}"myfile.rb"

  Run against standard input
    $ echo ':program' | seeing_is_believing
    :program  #{value}:program

  Pass the program in an argument
    $ seeing_is_believing -e ':program'
    :program  #{value}:program

  Remove previous output
    $ seeing_is_believing -e ":program" | seeing_is_believing --clean
    :program

  Aligning comments
    $ seeing_is_believing -s line -e $'123\\n4\\n\\n567890'
    123  #{value}123
    4  #{value}4

    567890  #{value}567890


    $ seeing_is_believing -s chunk -e $'123\\n4\\n\\n567890'
    123  #{value}123
    4    #{value}4

    567890  #{value}567890


    $ seeing_is_believing -s file -e $'123\\n4\\n\\n567890'
    123     #{value}123
    4       #{value}4

    567890  #{value}567890

  Run against a library you're working on by fixing the load path
    $ seeing_is_believing -I ./lib f.rb

  Require a file before yours is run (can be used in tandem with -I)
    $ seeing_is_believing -r pp -e 'pp [[*1..5]]*5'
    pp [[*1..5]]*5  #{value}[[1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5]]

    #{stdout}[[1, 2, 3, 4, 5],
    #{stdout} [1, 2, 3, 4, 5],
    #{stdout} [1, 2, 3, 4, 5],
    #{stdout} [1, 2, 3, 4, 5],
    #{stdout} [1, 2, 3, 4, 5]]

  Only update the lines you've marked
    $ seeing_is_believing -x -e $'1\\n2 # =>\\n3' |
    1
    2 #{value}2
    3

  Display a complex structure across multiple lines
    $ seeing_is_believing -x -e $'{foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}\\n#{value}'
    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    #{value} {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}

  Display a stream of events as they are seen
    $ seeing_is_believing -e $':a\\n:b\\n:c' --stream
    ["ruby_version",{"value":#{RUBY_VERSION.inspect}}]
    ["sib_version",{"value":#{SeeingIsBelieving::VERSION.inspect}}]
    ["filename",{"value":"/var/folders/7g/mbft22555w3_2nqs_h1kbglw0000gn/T/seeing_is_believing_temp_dir20150116-49548-kr0xop/program.rb"}]
    ["max_line_captures",{"value":-1,"is_infinity":true}]
    ["num_lines",{"value":3}]
    ["line_result",{"type":"inspect","line_number":1,"inspected":":a"}]
    ["line_result",{"type":"inspect","line_number":2,"inspected":":b"}]
    ["line_result",{"type":"inspect","line_number":3,"inspected":":c"}]
    ["event_stream_closed",{"side":"producer"}]
    ["stderr_closed",{"side":"producer"}]
    ["stdout_closed",{"side":"producer"}]
    ["exitstatus",{"value":0}]
    ["finished",{}]
EXAMPLES
  end
end
