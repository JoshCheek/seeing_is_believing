Feature: Using flags

  Sometimes you want more control over what comes out, for that we give you flags.

  Scenario: --start-line
    Given the file "start_line.rb":
    """
    1 + 1
    2
    3
    """
    When I run "seeing_is_believing --start-line 2 start_line.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
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
    When I run "seeing_is_believing --end-line 2 end_line.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
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
    When I run "seeing_is_believing --start-line 2 --end-line 3 start_and_end_line.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
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
    When I run "seeing_is_believing --result-length 10 result_lengths.rb"
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

  @wip
  Scenario: --line-length sets the total length of a given line
    Given the file "line_lengths.rb":
    """
    $stdout.puts "a"*100
    $stderr.puts "a"*100

    "aaa"
    "aaaa"

    raise        "a"*100
    """
    When I run "seeing_is_believing --line-length 32 line_lengths.rb"
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
    When I run "seeing_is_believing --line-length 12 line_lengths2.rb"
    Then stdout is "12345 # => ."
    When I run "seeing_is_believing --line-length 11 line_lengths2.rb"
    Then stdout is "12345"

  # Scenario: constrained by shorter of --line-length and --result-length
  #   Given the file "nine_digits.rb":
  #   """
  #   123456789
  #   """
  #   When I run "seeing_is_believing --result-length 20 --line-length 6 nine_digits.rb"
  #   Then stderr is empty
  #   And the exit status is 0
  #   And stdout is:
  #   """
  #   123456789 # => 12345
  #   """
  #   When I run "seeing_is_believing --result-length 22 --line-length 6 nine_digits.rb"
  #   Then stderr is empty
  #   And the exit status is 0
  #   And stdout is:
  #   """
  #   123456789 # => 123456
  #   """


  Scenario: --help
    When I run "seeing_is_believing --help"
    Then stderr is empty
    And the exit status is 0
    And stdout includes "Usage"
