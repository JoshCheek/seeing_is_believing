# encoding: utf-8
require 'seeing_is_believing/version'

class SeeingIsBelieving
  module Binary
    def self.help_screen(include_examples, markers)
      value_marker     = markers.fetch(:value)
      exception_marker = markers.fetch(:exception)
      stdout_marker    = markers.fetch(:stdout)
      stderr_marker    = markers.fetch(:stderr)

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
  -D,  --result-length n         # max length of the portion after the "#{value_marker}"
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
    __FILE__  #{value_marker}"myfile.rb"

  Run against standard input
    $ echo ':program' | seeing_is_believing
    :program  #{value_marker}:program

  Pass the program in an argument
    $ seeing_is_believing -e ':program'
    :program  #{value_marker}:program

  Remove previous output
    $ seeing_is_believing -e ":program" | seeing_is_believing --clean
    :program

  Aligning comments
    $ seeing_is_believing -s line -e $'123\\n4\\n\\n567890'
    123  #{value_marker}123
    4  #{value_marker}4

    567890  #{value_marker}567890


    $ seeing_is_believing -s chunk -e $'123\\n4\\n\\n567890'
    123  #{value_marker}123
    4    #{value_marker}4

    567890  #{value_marker}567890


    $ seeing_is_believing -s file -e $'123\\n4\\n\\n567890'
    123     #{value_marker}123
    4       #{value_marker}4

    567890  #{value_marker}567890

  Run against a library you're working on by fixing the load path
    $ seeing_is_believing -I ./lib f.rb

  Require a file before yours is run (can be used in tandem with -I)
    $ seeing_is_believing -r pp -e 'pp [[*1..5]]*5'
    pp [[*1..5]]*5  #{value_marker}[[1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5]]

    #{stdout_marker}[[1, 2, 3, 4, 5],
    #{stdout_marker} [1, 2, 3, 4, 5],
    #{stdout_marker} [1, 2, 3, 4, 5],
    #{stdout_marker} [1, 2, 3, 4, 5],
    #{stdout_marker} [1, 2, 3, 4, 5]]

  Only update the lines you've marked
    $ seeing_is_believing -x -e $'1\\n2 # =>\\n3' |
    1
    2 #{value_marker}2
    3

  Display a complex structure across multiple lines
    $ seeing_is_believing -x -e $'{foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}\\n#{value_marker}'
    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    #{value_marker} {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
EXAMPLES
    end
  end
end
