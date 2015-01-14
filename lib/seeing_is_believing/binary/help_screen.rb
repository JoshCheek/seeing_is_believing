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

  If no filename is provided, the binary will read the program from standard input.

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
