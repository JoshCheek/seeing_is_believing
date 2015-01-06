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


  Scenario: --number-of-captures determines how many times a line will be recorded
    Given the file "number_of_captures.rb":
    """
    5.times do |i|
      i
    end
    """
    When I run "seeing_is_believing --number-of-captures 4 number_of_captures.rb"
    Then stdout is:
    """
    5.times do |i|  # => 5
      i             # => 0, 1, 2, 3, ...
    end             # => 5
    """
    When I run "seeing_is_believing --number-of-captures 5 number_of_captures.rb"
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
    Given the file "utf-8.rb" "'ç'"
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


  Scenario: --timeout
    Given the file "will_timeout.rb" "sleep 1"
    When I run "seeing_is_believing --timeout 0.1 will_timeout.rb"
    Then stdout is empty
    And the exit status is 2
    And stderr is "Timeout Error after 0.1 seconds!"


  Scenario: --timeout
    Given the file "will_not_timeout.rb" "1 + 1"
    When I run "seeing_is_believing --timeout 1.0 will_not_timeout.rb"
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


  Scenario: --inherit-exit-status
    Given the file "exit_status.rb" "exit 123"
    When I run "seeing_is_believing exit_status.rb"
    Then the exit status is 1
    When I run "seeing_is_believing --inherit-exit-status exit_status.rb"
    Then the exit status is 123


  # Show that Ruby exceptions exit with 1, and --inherit-exit-status does as well
  Scenario: --inherit-exit-status
    Given the file "exception_exit_status.rb" "raise Exception"
    When I run "ruby exception_exit_status.rb"
    Then the exit status is 1
    When I run "seeing_is_believing --inherit-exit-status exception_exit_status.rb"
    Then the exit status is 1


  Scenario: --inherit-exit-status in an at_exit block
    Given the file "exit_status_in_at_exit_block.rb" "at_exit { exit 10 }"
    When I run "seeing_is_believing exit_status_in_at_exit_block.rb"
    Then the exit status is 1
    When I run "seeing_is_believing --inherit-exit-status exit_status_in_at_exit_block.rb"
    Then the exit status is 10


  Scenario: --debug
    Given the file "simple_program.rb":
    """
    # encoding: utf-8
    1# 123
    2
    """
    When I run "seeing_is_believing --debug simple_program.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout includes "TRANSLATED PROGRAM:"
    And stdout includes "$SiB"
    And stdout includes "RESULT:"
    And stdout includes "@results="
    And stdout includes "OUTPUT:"
    And stdout includes:
    """
    # encoding: utf-8
    1# 123
    2  # => 2
    """

  Scenario: --json
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
        "stdout": "b\n",
        "stderr": "c\n",
        "exit_status": 1
      }
    """

