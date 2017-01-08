Feature: Flags that are deprecated

  Features get added, features get removed.
  Don't want to blow up just b/c of removal of some feature.
  As such, these flags will continue to not blow up,
  even though they won't work anymore

  Scenario: --shebang with errors
    When I run "seeing_is_believing -e 123 --shebang path/to/bin"
    Then stderr is empty
    And stdout is "123  # => 123"
    And the exit status is 0

  Scenario: --shebang with errors
    When I run "seeing_is_believing not_a_file.rb --shebang path/to/bin"
    Then stdout is empty
    And stderr is:
    """
    Error: not_a_file.rb does not exist!
    Deprecated: `--shebang path/to/bin` SiB now uses the Ruby it was invoked with
    """

  Scenario: --number-of-captures without errors
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

  Scenario: --shebang with errors
    When I run "seeing_is_believing --shebang not/a/thing not_a_file.rb"
    Then stdout is empty
    And stderr is:
    """
    Error: not_a_file.rb does not exist!
    Deprecated: `--shebang not/a/thing` SiB now uses the Ruby it was invoked with
    """

  Scenario: --number-of-captures with errors
    When I run "seeing_is_believing not_a_file.rb --number-of-captures 2"
    Then stdout is empty
    And stderr is:
    """
    Error: not_a_file.rb does not exist!
    Deprecated: `--number-of-captures 2` use --max-line-captures instead
    """

  Scenario: --inherit-exit-status without errors
    Given the file "deprecated_inherit_exit_status.rb" "exit 123"
    When I run "seeing_is_believing deprecated_inherit_exit_status.rb --inherit-exit-status"
    Then stdout is "exit 123"
    And stderr is empty
    And the exit status is 123

  Scenario: --inherit-exit-status with errors
    When I run "seeing_is_believing not_a_file.rb --inherit-exit-status"
    Then stdout is empty
    And stderr is:
    """
    Error: not_a_file.rb does not exist!
    Deprecated: `--inherit-exit-status` Dash has been removed for consistency, use --inherit-exitstatus
    """

  Scenario: -K without errors
    Given the file "deprecated_K.rb" "__ENCODING__"
    When I run "seeing_is_believing -Ke deprecated_K.rb"
    Then stdout is '__ENCODING__  # => #<Encoding:EUC-JP>'
    And stderr is empty
    When I run "seeing_is_believing -Ku deprecated_K.rb"
    Then stdout is '__ENCODING__  # => #<Encoding:UTF-8>'
    And stderr is empty

  Scenario: -K with errors
    Given the file "deprecated_K.rb" "__ENCODING__"
    When I run "seeing_is_believing -Ke not_a_file.rb"
    Then stdout is empty
    And stderr is:
    """
    Error: not_a_file.rb does not exist!
    Deprecated: `-Ke` The ability to set encodings is deprecated. If you need this, details are at https://github.com/JoshCheek/seeing_is_believing/wiki/Encodings
    """
