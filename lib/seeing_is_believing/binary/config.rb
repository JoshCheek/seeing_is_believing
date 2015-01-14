# encoding: utf-8
require 'seeing_is_believing'
require 'seeing_is_believing/binary/marker'

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
      class Markers < HashStruct
        attribute(:value)     { Marker.new text: '# => ', regex: '^#\s*=>\s*' }
        attribute(:exception) { Marker.new text: '# ~> ', regex: '^#\s*~>\s*' }
        attribute(:stdout)    { Marker.new text: '# >> ', regex: '^#\s*>>\s*' }
        attribute(:stderr)    { Marker.new text: '# !> ', regex: '^#\s*!>\s*' }
      end

      # passed to annotator.call
      class AnnotatorOptions < HashStruct
        attribute(:alignment_strategy) { AlignChunk }
        attribute(:markers)            { Markers.new }
        attribute(:max_line_length)    { Float::INFINITY }
        attribute(:max_result_length)  { Float::INFINITY }
      end

      predicate(:print_version)       { false }
      predicate(:print_cleaned)       { false }
      predicate(:print_help)          { false }
      predicate(:result_as_json)      { false }
      predicate(:inherit_exit_status) { false }
      predicate(:debug)               { false }

      attribute(:body)                { nil }
      attribute(:filename)            { nil }
      attribute(:errors)              { [] }
      attribute(:deprecations)        { [] }
      attribute(:timeout_seconds)     { 0 }
      attribute(:annotator)           { AnnotateEveryLine }
      attribute(:debugger)            { Debugger::Null }
      attribute(:markers)             { Markers.new }
      attribute(:help_screen)         { Binary.help_screen false, Markers.new } # TODO: how about help_screen and help_screen_extended
      attribute(:lib_options)         { SeeingIsBelieving::Options.new }       # passed to SeeingIsBelieving.new
      attribute(:annotator_options)   { AnnotatorOptions.new }

      def parse_args(args, debug_stream)
        as        = nil
        filenames = []
        args      = args.dup

        extract_positive_int_for = lambda do |flagname, &on_success|
          string = args.shift
          int    = string.to_i
          if int.to_s == string && 0 < int
            on_success.call int
          else
            self.errors << "#{flagname} expects a positive integer argument"
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
            errors << "#{flagname} expects a positive float or integer argument"
          end
        end

        deprecated_arg = Class.new HashStruct do
          attributes :args, :explanation
          def to_s
            "Deprecated: `#{args.join ' '}` #{explanation}"
          end
        end

        saw_deprecated = lambda do |explanation, *args|
          self.deprecations << deprecated_arg.new(explanation: explanation, args: args)
        end

        # TODO: next_arg(error_message, success: callback, failure: callback)
        next_arg = lambda do |error_message, &on_success|
          arg = args.shift
          arg ? on_success.call(arg) :
                self.errors << error_message
          arg
        end

        until args.empty?
          case (arg = args.shift)
          when '-c', '--clean'
            self.print_cleaned = true

          when '-v', '--version'
            self.print_version = true

          when '-x', '--xmpfilter-style'
            self.annotator = AnnotateMarkedLines

          when '-i', '--inherit-exit-status'
            self.inherit_exit_status = true

          when '-j', '--json'
            self.result_as_json = true

          when '-h', '--help'
            self.print_help = true

          when '-h+', '--help+'
            self.print_help  = true
            self.help_screen = Binary.help_screen(true, markers)

          when '-g', '--debug'
            self.debug                = true
            self.debugger             = Debugger.new stream: debug_stream, colour: true
            self.lib_options.debugger = debugger

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
            next_arg.call "#{arg} expected a filename as the following argument but did not see one" do |filename|
              self.lib_options.require << filename
            end

          when '-I', '--load-path'
            next_arg.call "#{arg} expected a directory as the following argument but did not see one" do |dir|
              self.lib_options.load_path << dir
            end

          when '-e', '--program'
            next_arg.call "#{arg} expected a program as the following argument but did not see one" do |program|
              self.body = program
            end

          when '-a', '--as'
            next_arg.call "#{arg} expected a filename as the following argument but did not see one"  do |filename|
              as = filename
            end

          when '-s', '--alignment-strategy'
            strategies     = {'file' => AlignFile, 'chunk' => AlignChunk, 'line' => AlignLine}
            strategy_names = strategies.keys.join(', ')
            next_arg.call "#{arg} expected an alignment strategy as the following argument but did not see one (choose from: #{strategy_names})" do |name|
              if strategies[name]
                self.annotator_options.alignment_strategy = strategies[name]
              else
                errors << "#{arg} does not know #{name}, only knows: #{strategy_names}"
              end
            end

          when /\A-K(.+)/
            self.lib_options.encoding = $1

          when '-K', '--encoding'
            next_arg.call "#{arg} expects an encoding, see `man ruby` for possibile values" do |encoding|
              self.lib_options.encoding = encoding
            end

          when '--shebang'
            executable = args.shift
            if executable
              saw_deprecated.call "SiB now uses the Ruby it was invoked with", arg, executable
            else
              errors << "#{arg} expected an arg: path to a ruby executable"
              saw_deprecated.call "SiB now uses the Ruby it was invoked with", arg
            end

          when /^(-.|--.*)$/
            self.errors << "Unknown option: #{arg.inspect}"

          when /^-[^-]/
            shortflags = arg[1..-1].chars.to_a # TODO: look for a sweet regex instead of this annoying algorithm
            plusidx    = shortflags.index('+') || 0
            if 0 < plusidx
              shortflags[plusidx-1] << '+'
              shortflags.delete_at plusidx
            end
            args.unshift *shortflags.map { |flag| "-#{flag}" }

          else
            filenames << arg
          end
        end

        filenames.size > 1 &&
          errors << "Can only have one filename, but had: #{filenames.map(&:inspect).join ', '}"

        self.filename                  = filenames.first
        self.lib_options.filename      = as || filename
        self.lib_options.annotate      = annotator.expression_wrapper(markers)
        self.lib_options.debugger      = debugger
        self.annotator_options.markers = markers

        self
      end

      def finalize(stdin, file_class)
        if filename && body
          errors << "Cannot give a program body and a filename to get the program body from."
        elsif filename && file_class.exist?(filename)
          self.lib_options.stdin = stdin
          self.body = file_class.read filename
        elsif filename
          errors << "#{filename} does not exist!"
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

  def Binary.help_screen(include_examples, markers)
    value  = markers[:value][:text]
    stdout = markers[:stdout][:text]

    <<FLAGS + (include_examples ? <<EXAMPLES : '')
Usage: seeing_is_believing [options] [filename]

  seeing_is_believing is a program and library that will evaluate a Ruby file and capture/display the results.

Notes:

  * If no filename or program (-e flag) are provided, the program will read from standard input.
  * The process's stdin will be passed to the program unless the program body is on stdin.
  * The exit status will be:
    0 - No errors
    1 - Displayable error (e.g. code raises an exception while running)
    2 - Non-displayable error (e.g. a syntax error, a timeout)
    n - The program's exit status if the --inherit-exit-status flag is set

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
  -i,  --inherit-exit-status     # exit with the exit status of the program being evaluated
       --shebang ruby-executable # if you want SiB to use some ruby other than the one in the path
  -v,  --version                 # print the version (#{VERSION})
  -h,  --help                    # help screen without examples
  -h+, --help+                   # help screen with examples
FLAGS

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
EXAMPLES
  end
end
