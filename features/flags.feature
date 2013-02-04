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

  Scenario: --help
    When I run "seeing_is_believing --help"
    Then stderr is empty
    And the exit status is 0
    And stdout includes "Usage"
