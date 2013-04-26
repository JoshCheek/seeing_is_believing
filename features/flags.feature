Feature: Using flags

  Sometimes you want more control over what comes out, for that we give you flags.

  Scenario: --start-line
    Given the file "start_line.rb":
    """
    1 + 1
    2
    3
    """
    When I run "seeing_is_believing -s file --start-line 2 start_line.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    """
    When I run "seeing_is_believing -s chunk --start-line 2 start_line.rb"
    Then stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    """
    When I run "seeing_is_believing -s line --start-line 2 start_line.rb"
    Then stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    """

  Scenario: --end-line
    Given the file "end_line.rb":
    """
    1
    2
    3 + 3
    """
    When I run "seeing_is_believing -s file --end-line 2 end_line.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1  # => 1
    2  # => 2
    3 + 3
    """
    When I run "seeing_is_believing -s chunk --end-line 2 end_line.rb"
    Then stdout is:
    """
    1  # => 1
    2  # => 2
    3 + 3
    """
    When I run "seeing_is_believing -s line --end-line 2 end_line.rb"
    Then stdout is:
    """
    1  # => 1
    2  # => 2
    3 + 3
    """

  Scenario: --start-line and --end-line
    Given the file "start_and_end_line.rb":
    """
    1 + 1
    2
    3
    4 + 4
    """
    When I run "seeing_is_believing -s file --start-line 2 --end-line 3 start_and_end_line.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    4 + 4
    """
    When I run "seeing_is_believing -s chunk --start-line 2 --end-line 3 start_and_end_line.rb"
    Then stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    4 + 4
    """
    When I run "seeing_is_believing -s line --start-line 2 --end-line 3 start_and_end_line.rb"
    Then stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    4 + 4
    """

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

  Scenario: --require
    Given the file "print_1.rb" "puts 1"
    Given the file "print_2.rb" "puts 2"
    And the file "print_3.rb" "puts 3"
    When I run "seeing_is_believing --require ./print_1 --require ./print_2 print_3.rb"
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
    Given the file "print_1.rb" "puts 1"
    And the file "some_dir/print_2.rb" "puts 2"
    And the file "require_print_1.rb" "require 'print_1'"
    When I run "seeing_is_believing require_print_1.rb"
    Then the exit status is 1
    When I run "seeing_is_believing --load-path . -I ./some_dir -r print_2  require_print_1.rb"
    Then stderr is empty
    And stdout is:
    """
    require 'print_1'  # => true

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
    Given the file "example.rb" "1+1"
    Given I have the stdin content:
    """
    1+1
    __FILE__
    """
    When I run "seeing_is_believing --as example.rb"
    Then stderr is empty
    Then the exit status is 0
    And stdout is:
    """
    1+1       # => 2
    __FILE__  # => "example.rb"
    """

  Scenario: --as and -e
    Given the file "example.rb" "1+1"
    When I run 'seeing_is_believing --as example.rb -e "__FILE__"'
    Then stderr is empty
    And the exit status is 0
    And stdout is '__FILE__  # => "example.rb"'

  Scenario: --clean
    Given the file "example.rb":
    """
    1 + 1  # => not 2
    2 + 2  # ~> Exception, something


    # >> some stdout output

    # !> some stderr output
    __END__
    1
    """
    When I run "seeing_is_believing --clean example.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
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

  Scenario: --timeout
    Given the file "example.rb" "sleep 1"
    When I run "seeing_is_believing --timeout 0.1 example.rb"
    Then stdout is empty
    And the exit status is 2
    And stderr is "Timeout Error after 0.1 seconds!"

  Scenario: --timeout
    Given the file "example.rb" "1 + 1"
    When I run "seeing_is_believing --timeout 1.0 example.rb"
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
