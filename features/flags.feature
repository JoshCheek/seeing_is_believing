Feature: Using flags

  Sometimes you want more control over what comes out, for that we give you flags.
  Note that some flags are significant enough to have their own file.

  Scenario: --result-length sets the length of the portion including and after the # =>
    Given the file "result_lengths.rb":
    """
    $stdout.puts "a"*100
    $stderr.puts "a"*100

                 "a"
                 "aa"
                 "aaa"
                 "aaaa"

    raise        "a"*100
    """
    When I run "seeing_is_believing -s file --result-length 10 result_lengths.rb"
    Then stderr is empty
    And stdout is:
    """
    $stdout.puts "a"*100  # => nil
    $stderr.puts "a"*100  # => nil

                 "a"      # => "a"
                 "aa"     # => "aa"
                 "aaa"    # => "aaa"
                 "aaaa"   # => "a...

    raise        "a"*100  # ~> Ru...

    # >> aa...

    # !> aa...

    # ~> Ru...
    # ~> aa...
    # ~>
    # ~> re...
    """


  Scenario: --line-length sets the total length of a given line
    Given the file "line_lengths.rb":
    """
    $stdout.puts "a"*100
    $stderr.puts "a"*100

    "aaa"
    "aaaa"

    raise        "a"*100
    """
    When I run "seeing_is_believing -s file --line-length 32 line_lengths.rb"
    Then stderr is empty
    And stdout is:
    """
    $stdout.puts "a"*100  # => nil
    $stderr.puts "a"*100  # => nil

    "aaa"                 # => "aaa"
    "aaaa"                # => "a...

    raise        "a"*100  # ~> Ru...

    # >> aaaaaaaaaaaaaaaaaaaaaaaa...

    # !> aaaaaaaaaaaaaaaaaaaaaaaa...

    # ~> RuntimeError
    # ~> aaaaaaaaaaaaaaaaaaaaaaaa...
    # ~>
    # ~> line_lengths.rb:7:in `<m...
    """
    Given the file "line_lengths2.rb":
    """
    12345
    """
    When I run "seeing_is_believing --line-length 1 line_lengths2.rb"
    Then stdout is "12345"
    When I run "seeing_is_believing --line-length 15 line_lengths2.rb"
    Then stdout is "12345  # => ..."
    When I run "seeing_is_believing --line-length 14 line_lengths2.rb"
    Then stdout is "12345"


  Scenario: --max-line-captures determines how many times a line will be recorded
    Given the file "max_line_captures.rb":
    """
    5.times do |i|
      i
    end
    """
    When I run "seeing_is_believing --max-line-captures 4 max_line_captures.rb"
    Then stdout is:
    """
    5.times do |i|  # => 5
      i             # => 0, 1, 2, 3, ...
    end             # => 5
    """
    When I run "seeing_is_believing --max-line-captures 5 max_line_captures.rb"
    Then stdout is:
    """
    5.times do |i|  # => 5
      i             # => 0, 1, 2, 3, 4
    end             # => 5
    """


  Scenario: --require
    Given the file "r_print_1.rb" "puts 1"
    Given the file "r_print_2.rb" "puts 2"
    And the file "r_print_3.rb" "puts 3"
    When I run "seeing_is_believing --require ./r_print_1 --require ./r_print_2 r_print_3.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    puts 3  # => nil

    # >> 1
    # >> 2
    # >> 3
    """


  Scenario: --program
    When I run "seeing_is_believing --program '1'"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1  # => 1
    """


  Scenario: --load-path
    Given the file "lp_print_1.rb" "puts 1"
    And the file "some_dir/lp_print_2.rb" "puts 2"
    And the file "require_lp_print_1.rb" "require 'lp_print_1'"
    When I run "seeing_is_believing require_lp_print_1.rb"
    Then the exit status is 1
    When I run "seeing_is_believing --load-path . -I ./some_dir -r lp_print_2  require_lp_print_1.rb"
    Then stderr is empty
    And stdout is:
    """
    require 'lp_print_1'  # => true

    # >> 2
    # >> 1
    """
    And the exit status is 0


  Scenario: --encoding
    Given the binary file "utf-8.rb" "'ç'"
    When I run "seeing_is_believing --encoding u utf-8.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    'ç'  # => "ç"
    """


  Scenario: --as and stdin
    Given the stdin content:
    """
    __FILE__
    """
    When I run "seeing_is_believing --as as_and_stdin.rb"
    Then stderr is empty
    Then the exit status is 0
    And stdout is:
    """
    __FILE__  # => "as_and_stdin.rb"
    """


  Scenario: --as and -e
    When I run 'seeing_is_believing --as as_and_e.rb -e "__FILE__"'
    Then stderr is empty
    And the exit status is 0
    And stdout is '__FILE__  # => "as_and_e.rb"'


  Scenario: --as and filename
    Given the file "as_and_filename.rb" "__FILE__"
    When I run 'seeing_is_believing as_and_filename.rb --as not_as_and_filename.rb'
    Then stderr is empty
    And the exit status is 0
    And stdout is '__FILE__  # => "not_as_and_filename.rb"'


  Scenario: --clean
    Given the file "uncleaned.rb":
    """
    # comment # => still a comment
    1 + 1  # => not 2
    2 + 2  # ~> Exception, something


    # >> some stdout output

    # !> some stderr output
    __END__
    1
    """
    When I run "seeing_is_believing --clean uncleaned.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    # comment # => still a comment
    1 + 1
    2 + 2

    __END__
    1
    """


  Scenario: --clean on an invalid file will clean
    When I run 'seeing_is_believing --clean -e "1+  # => lkj"'
    Then stderr is empty
    And the exit status is 0
    And stdout is '1+'


  Scenario: --version
    When I run 'seeing_is_believing --version'
    Then stderr is empty
    And the exit status is 0
    And stdout is '{{SeeingIsBelieving::VERSION}}'


  Scenario: --help
    When I run "seeing_is_believing --help"
    Then stderr is empty
    And the exit status is 0
    And stdout includes "Usage"
    And stdout does not include "Examples:"


  Scenario: --help+
    When I run "seeing_is_believing --help+"
    Then stderr is empty
    And the exit status is 0
    And stdout includes "Usage"
    And stdout includes "Examples:"


  Scenario: --timeout-seconds
    Given the file "will_timeout.rb" "sleep 1"
    When I run "seeing_is_believing --timeout-seconds 0.1 will_timeout.rb"
    Then stdout is empty
    And the exit status is 2
    And stderr is "Timeout Error after 0.1 seconds!"


  Scenario: --timeout-seconds
    Given the file "will_not_timeout.rb" "1 + 1"
    When I run "seeing_is_believing --timeout-seconds 1.0 will_not_timeout.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is "1 + 1  # => 2"


  Scenario: --alignment-strategy file
     Given the file "file_alignments.rb":
    """
    # comment
    1

    =begin
    multiline comment
    =end
    1 + 1
    1 + 1 + 1
    """
    When I run "seeing_is_believing --alignment-strategy file file_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    # comment
    1          # => 1

    =begin
    multiline comment
    =end
    1 + 1      # => 2
    1 + 1 + 1  # => 3
    """


  Scenario: --alignment-strategy chunk
    Given the file "chunk_alignments.rb":
    """
    # comment
    1

    =begin
    multiline comment
    =end
    1 + 1
    1 + 1 + 1

    1+1+1
    1+1

    1 + 1
    # comment in the middle!
    1 + 1 + 1 + 1
    1 + 1
    """
    When I run "seeing_is_believing --alignment-strategy chunk chunk_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    # comment
    1  # => 1

    =begin
    multiline comment
    =end
    1 + 1      # => 2
    1 + 1 + 1  # => 3

    1+1+1  # => 3
    1+1    # => 2

    1 + 1          # => 2
    # comment in the middle!
    1 + 1 + 1 + 1  # => 4
    1 + 1          # => 2
    """


  Scenario: --alignment-strategy line
    Given the file "line_alignments.rb":
    """
    # comment
    1

    =begin
    multiline comment
    =end
    1 + 1
    1 + 1 + 1
    """
    When I run "seeing_is_believing --alignment-strategy line line_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    # comment
    1  # => 1

    =begin
    multiline comment
    =end
    1 + 1  # => 2
    1 + 1 + 1  # => 3
    """


  Scenario: --inherit-exitstatus causes SiB to exit with the status of the evaluated file
    Given the file "exitstatus.rb" "exit 123"

    When I run "seeing_is_believing exitstatus.rb"
    Then the exit status is 1
    And  stderr is empty
    And stdout is "exit 123"

    When I run "seeing_is_believing -i exitstatus.rb"
    Then the exit status is 123
    And  stderr is empty
    And stdout is "exit 123"


  Scenario: --inherit-exitstatus works with exit!
    Given the file "exit_bang.rb":
    """
    :hello
    exit! 100
    """

    When I run "seeing_is_believing exit_bang.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout is:
    """
    :hello     # => :hello
    exit! 100
    """

    When I run "seeing_is_believing -i exit_bang.rb"
    Then stderr is empty
    And the exit status is 100
    And stdout is:
    """
    :hello     # => :hello
    exit! 100
    """


  # Show that Ruby exceptions exit with 1, and --inherit-exitstatus does as well
  Scenario: --inherit-exitstatus
    Given the file "exception_exitstatus.rb" "raise Exception"
    When I run "ruby exception_exitstatus.rb"
    Then the exit status is 1
    When I run "seeing_is_believing -i exception_exitstatus.rb"
    Then the exit status is 1


  Scenario: --inherit-exitstatus in an at_exit block
    Given the file "exitstatus_in_at_exit_block.rb" "at_exit { exit 10 }"
    When I run "seeing_is_believing exitstatus_in_at_exit_block.rb"
    Then the exit status is 1
    When I run "seeing_is_believing -i exitstatus_in_at_exit_block.rb"
    Then the exit status is 10


  Scenario: --debug
    Given the file "simple_program.rb":
    """
    # encoding: utf-8
    1# 123
    2
    """
    When I run "seeing_is_believing --debug simple_program.rb"
    Then stdout is empty
    And the exit status is 0
    And stderr includes "REWRITTEN PROGRAM:"
    And stderr includes "$SiB"
    And stderr includes "EVENTS:"
    And stderr includes "OUTPUT:"
    And stderr includes:
    """
    # encoding: utf-8
    1# 123
    2  # => 2
    """

  Scenario: --json without exceptions
    Given the file "simple_json.rb":
    """
    3.times do |i|
      i.to_s
    end
    """
    When I run "seeing_is_believing --json simple_json.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is the JSON:
    """
      { "lines": {
          "1": ["3"],
          "2": ["\"0\"", "\"1\"", "\"2\""],
          "3": ["3"]
        },
        "exception":  null,
        "exceptions": [],
        "stdout":     "",
        "stderr":     "",
        "exitstatus": 0
      }
    """

  Scenario: --json with exceptions
    Given the file "all_kinds_of_output.rb":
    """
    3.times do |i|
      i.to_s
    end
    $stdout.puts "b"
    $stderr.puts "c"
    raise "omg"
    """
    When I run "seeing_is_believing --json all_kinds_of_output.rb"
    Then stderr is empty
    And  the exit status is 0
    # Use the exceptions array rather than the singule exception, it's less correct
    # as there can be multiple exceptions. It only exists for backwards compatibility.
    And  stdout is the JSON:
    """
      { "lines": {
          "1": ["3"],
          "2": ["\"0\"", "\"1\"", "\"2\""],
          "3": ["3"],
          "4": ["nil"],
          "5": ["nil"],
          "6": []
        },
        "exception": {
          "line_number_in_this_file": 6,
          "class_name":               "RuntimeError",
          "message":                  "omg",
          "backtrace":                ["all_kinds_of_output.rb:6:in `<main>'"]
        },
        "exceptions": [{
          "line_number_in_this_file": 6,
          "class_name":               "RuntimeError",
          "message":                  "omg",
          "backtrace":                ["all_kinds_of_output.rb:6:in `<main>'"]
        }],
        "stdout": "b\n",
        "stderr": "c\n",
        "exitstatus": 1
      }
    """

  Scenario: --stream prints events from the event stream as they are seen
    Given the file "record_event_stream.rb" "3.times { |i| p i }"
    When I run "seeing_is_believing record_event_stream.rb --stream"
    Then stderr is empty
    And the exit status is 0
    And stdout includes:
    """
    ["stdout",{"value":"0\n"}]
    """
    And stdout includes:
    """
    ["exitstatus",{"value":0}]
    """
    And stdout includes:
    """
    ["max_line_captures",{"value":-1,"is_infinity":true}]
    """

  Scenario: --stream respects the exit status
    When I run "seeing_is_believing -ie 'exit 12' --stream"
    Then stderr is empty
    And the exit status is 12

  Scenario: --stream sees leading data even with a hostile BEGIN block.
    When I run "seeing_is_believing -e 'BEGIN { exit! }' --stream"
    Then stdout includes:
    """
    ["sib_version",{"value":"{{SeeingIsBelieving::VERSION}}"}]
    """

  Scenario: --stream emits a timeout event and finishes successfully when the process times out.
    When I run "seeing_is_believing -e 'loop { sleep 1 }' -t 0.01 --stream"
    Then the exit status is 2
    And stderr is "Timeout Error after 0.01 seconds!"
    And stdout includes:
    """
    ["finished",{}]
    """
    And stdout includes:
    """
    ["timeout",{"seconds":0.01}]
    """

  Scenario: --ignore-unknown-flags prevents errors on unknown flags for forward compatibility
    When I run "seeing_is_believing -e '1' --ignore-unknown-flags --zomg-wat"
    Then the exit status is 0
    And stderr is empty
    And stdout is "1  # => 1"

  Scenario: --interline-align and --no-interline-align determine whether adjacent lines with the same number of results get lined up, it defaults to --align
    Given the file "interline_alignment.rb":
    """
    3.times do |num|
      num
        .to_s
    end
    """
    When I run "seeing_is_believing interline_alignment.rb"
    Then stderr is empty
    And  the exit status is 0
    And  stdout is:
    """
    3.times do |num|  # => 3
      num             # => 0,   1,   2
        .to_s         # => "0", "1", "2"
    end               # => 3
    """
    When I run "seeing_is_believing --interline-align interline_alignment.rb"
    Then stderr is empty
    And  the exit status is 0
    And  stdout is:
    """
    3.times do |num|  # => 3
      num             # => 0,   1,   2
        .to_s         # => "0", "1", "2"
    end               # => 3
    """
    When I run "seeing_is_believing --no-interline-align interline_alignment.rb"
    Then stderr is empty
    And  the exit status is 0
    And  stdout is:
    """
    3.times do |num|  # => 3
      num             # => 0, 1, 2
        .to_s         # => "0", "1", "2"
    end               # => 3
    """


  Scenario: --local-cwd causes the current working directory to be the same as the file
    Given the file "subdir/cwd_of_file_test.rb" "__FILE__"
    When I run "seeing_is_believing subdir/cwd_of_file_test.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is '__FILE__  # => "subdir/cwd_of_file_test.rb"'
    When I run "seeing_is_believing subdir/cwd_of_file_test.rb --local-cwd"
    Then stderr is empty
    And the exit status is 0
    And stdout is '__FILE__  # => "cwd_of_file_test.rb"'


  Scenario: --toggle-mark adds a mark to the line if it is unmarked and exists
    Given the file "unmarked.rb":
    """
    1
    2
    """
    When I run "seeing_is_believing unmarked.rb --toggle-mark 1"
    Then stderr is empty
    And the exit status is 0
    And stdout is '{{"1  # => \n2"}}'
    When I run "seeing_is_believing unmarked.rb --toggle-mark 2"
    Then stderr is empty
    And the exit status is 0
    And stdout is '{{"1\n2  # => "}}'
    When I run "seeing_is_believing unmarked.rb --toggle-mark 3"
    Then stderr is empty
    And the exit status is 0
    And stdout is '{{"1\n2"}}'


  Scenario: --toggle-mark doesn't add a mark to the line if it has a comment or can't be commented
    Given the file "no_toggle_line_here.rb":
    """
    1 # comment
    "2
    "
    """
    When I run "seeing_is_believing no_toggle_line_here.rb --toggle-mark 1"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 # comment
    "2
    "
    """
    When I run "seeing_is_believing no_toggle_line_here.rb --toggle-mark 2"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 # comment
    "2
    "
    """
    When I run "seeing_is_believing no_toggle_line_here.rb --toggle-mark 3"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 # comment
    "2
    "  # =>{{" "}}
    """


  Scenario: --toggle-mark removes a mark from the line if it is marked and exists
    Given the file "marked.rb":
    """
    1      # =>
    2 + 2  # =>
    """
    When I run "seeing_is_believing marked.rb --toggle-mark 1"
    Then stderr is empty
    And the exit status is 0
    And stdout is '{{"1\n2 + 2  # => "}}'
    When I run "seeing_is_believing marked.rb --toggle-mark 2"
    Then stderr is empty
    And the exit status is 0
    And stdout is '{{"1      # => \n2 + 2"}}'
    When I run "seeing_is_believing marked.rb --toggle-mark 3"
    Then stderr is empty
    And the exit status is 0
    And stdout is '{{"1      # => \n2 + 2  # => "}}'


  Scenario: --toggle-mark removes error lines, and stdout/stderr output
    Given the file "output_to_toggle_off.rb":
    """
    1 + "a" # ~> b
    # >> c
    # !> d
    # ~> e
    """
    When I run "seeing_is_believing output_to_toggle_off.rb --toggle-mark 1"
    Then stdout is:
    """
    1 + "a"
    # >> c
    # !> d
    # ~> e
    """
    When I run "seeing_is_believing output_to_toggle_off.rb --toggle-mark 2"
    Then stdout is:
    """
    1 + "a" # ~> b

    # !> d
    # ~> e
    """
    When I run "seeing_is_believing output_to_toggle_off.rb --toggle-mark 3"
    Then stdout is:
    """
    1 + "a" # ~> b
    # >> c

    # ~> e
    """
    When I run "seeing_is_believing output_to_toggle_off.rb --toggle-mark 4"
    Then stdout is:
    """
    1 + "a" # ~> b
    # >> c
    # !> d
    """


  Scenario: --toggle-mark respects the --alignment-strategy of file and updates any existing annotations to respect it
    Given the file "toggle_mark_with_file_alignment.rb":
    """
    1

    1 + 1 # => 2
    1 + 1 + 1 # => 3
    1 + 1 + 1 + 1
    """
    When I run "seeing_is_believing --toggle-mark 1 --alignment-strategy file toggle_mark_with_file_alignment.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1              # =>{{" "}}

    1 + 1          # => 2
    1 + 1 + 1      # => 3
    1 + 1 + 1 + 1
    """
    When I run "seeing_is_believing --toggle-mark 3 --alignment-strategy file toggle_mark_with_file_alignment.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1

    1 + 1
    1 + 1 + 1      # => 3
    1 + 1 + 1 + 1
    """


  Scenario: --toggle-mark respects the --alignment-strategy of chunk and updates any existing annotations to respect it
    Given the file "toggle_mark_with_chunk_alignments.rb":
    """
    1+1# => 2
    1+1+1
    1+1+1+1

    1 + 1
    # comment in the middle!
    1
    """
    When I run "seeing_is_believing --toggle-mark 2 --alignment-strategy chunk toggle_mark_with_chunk_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1+1      # => 2
    1+1+1    # =>{{" "}}
    1+1+1+1

    1 + 1
    # comment in the middle!
    1
    """
    When I run "seeing_is_believing --toggle-mark 5 --alignment-strategy chunk toggle_mark_with_chunk_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1+1      # => 2
    1+1+1
    1+1+1+1

    1 + 1  # =>{{" "}}
    # comment in the middle!
    1
    """
    When I run "seeing_is_believing --toggle-mark 1 --alignment-strategy chunk toggle_mark_with_chunk_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1+1
    1+1+1
    1+1+1+1

    1 + 1
    # comment in the middle!
    1
    """


  Scenario: --toggle-mark respects the --alignment-strategy of line and updates any existing annotations to respect it
    Given the file "toggle_mark_with_line_alignments.rb":
    """
    1
    1 + 1# => x
    1 + 1 + 1
    """
    When I run "seeing_is_believing --toggle-mark 1 --alignment-strategy line toggle_mark_with_line_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1  # =>{{" "}}
    1 + 1  # => x
    1 + 1 + 1
    """
    When I run "seeing_is_believing --toggle-mark 2 --alignment-strategy line toggle_mark_with_line_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1
    1 + 1
    1 + 1 + 1
    """
    When I run "seeing_is_believing --toggle-mark 3 --alignment-strategy line toggle_mark_with_line_alignments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1
    1 + 1  # => x
    1 + 1 + 1  # =>{{" "}}
    """
