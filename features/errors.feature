Feature: Running the binary unsuccessfully

  Sometimes I mess up and use the program in a way that doesn't work.
  I'd like it to be helpful in these situations so I can fix my use.

  # show that it displalys next to the first place in the file
  # and should maybe print the stacktrace at the bottom
  Scenario: Raising exceptions
    Given the file "raises_exception.rb":
    """
    raise "ZOMG!"
    """
    And the file "requires_exception_raising_code.rb":
    """
    def first_defined
      second_defined
    end

    def second_defined
      require_relative 'raises_exception'
    end

    first_defined
    """
    When I run "seeing_is_believing requires_exception_raising_code.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout is:
    """
    def first_defined
      second_defined
    end                # => nil

    def second_defined
      require_relative 'raises_exception'  # ~> RuntimeError: ZOMG!
    end                                    # => nil

    first_defined
    """

  Scenario: Syntactically invalid file
    Given the file "invalid_syntax.rb":
    """
    'abc
    """
    When I run "seeing_is_believing invalid_syntax.rb"
    Then stderr includes "1: unterminated string meets end of file"
    And the exit status is 2
    And stdout is empty

  Scenario: Passing a nonexistent file
    When I run "seeing_is_believing this_file_does_not_exist.rb"
    Then stderr is "this_file_does_not_exist.rb does not exist!"
    And the exit status is 2
    And stdout is empty

  Scenario: Passing unknown options
    Given the file "some_file" "1"
    When I run "seeing_is_believing --unknown-option"
    Then stderr is 'Unknown option: "--unknown-option"'
    And the exit status is 2
    And stdout is empty

  Scenario: Passing an unknown option with a value but forgetting the filename
    When I run "seeing_is_believing --unknown-option some-value"
    Then stderr is 'Unknown option: "--unknown-option"'
    And the exit status is 2
    And stdout is empty

  Scenario: Stack overflow
    Given the file "stack_overflow.rb":
    """
    def m() m end
    m
    """
    When I run "seeing_is_believing stack_overflow.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout is:
    """
    def m() m end  # ~> SystemStackError: stack level too deep
    m
    """

  Scenario: Total Fucking Failure
    Given the file "sib_will_utterly_die.rb" "BEGIN {}"
    When I run "seeing_is_believing sib_will_utterly_die.rb"
    Then stderr is not empty
    And the exit status is 2
    And stdout is empty
