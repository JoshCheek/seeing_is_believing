Feature: Flags that are deprecated

  Features get added, features get removed.
  Don't want to blow up just b/c of removal of some feature.
  As such, these flags will continue to not blow up,
  even though they won't work anymore

  Scenario: --shebang
    When I run "seeing_is_believing -e 123 --shebang not/a/thing"
    Then stderr is empty
    And stdout is "123  # => 123"
    And the exit status is 0

  Scenario: --number-of-captures
    Given the file "number_of_captures.rb":
    """
    5.times do |i|
      i
    end
    """
    When I run "seeing_is_believing --number-of-captures 2 number_of_captures.rb"
    Then stderr is empty
    And stdout is:
    """
    5.times do |i|  # => 5
      i             # => 0, 1, ...
    end             # => 5
    """
    And the exit status is 0
