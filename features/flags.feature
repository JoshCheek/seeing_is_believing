@not-implemented
Feature: Using flags

  Sometimes you want more control over what comes out, for that we give you flags.

  Scenario: --start-index
    Given the file "start_index.rb":
    """
    1 + 1
    2
    3
    """
    When I run "seeing_is_believing --start-index 2 start_index.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    """

  Scenario: --end-index
    Given the file "end_index.rb":
    """
    1
    2
    3 + 3
    """
    When I run "seeing_is_believing --end-index 2 end_index.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1  # => 1
    2  # => 2
    3 + 3
    """

  Scenario: --start-index and --end-index
    Given the file "start_and_end_index.rb":
    """
    1 + 1
    2
    3
    4 + 4
    """
    When I run "seeing_is_believing --start-index 2 --end-index 3 start_and_end_index.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 + 1
    2  # => 2
    3  # => 3
    4 + 4
    """
