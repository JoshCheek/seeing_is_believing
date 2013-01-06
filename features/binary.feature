Feature: Running the binary
  They say seeing is believing. So to believe that this works
  I want to see that it works by making a binary to use the lib.

  It should be approximately like xmpfilter, except that it should
  run against every line.

  Scenario: Some basic functionality
    Given the file "basic_functionality.rb":
    """
    5.times do |i|
      i * 2
    end

    def meth(n)
      n
    end

    # some invocations
    meth "12"
    meth "34"
    """
    When I run "seeing_is_believing basic_functionality.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    5.times do |i|
      i * 2         # => 0, 2, 4, 6, 8
    end             # => 5

    def meth(n)
      n             # => "12", "34"
    end             # => nil

    # some invocations
    meth "12"       # => "12"
    meth "34"       # => "34"
    """

  Scenario: Raising exceptions
    Given the file "raises_exception.rb":
    """
    1 + 1
    raise "ZOMG!"
    1 + 1
    """
    When I run "seeing_is_believing raises_exception.rb"
    Then stderr is "ZOMG!"
    And the exit status is 1
    And stdout is:
    """
    1 + 1          # => 2
    raise "ZOMG!"  # ~> RuntimeError: ZOMG!
    1 + 1
    """

  Scenario: Passing previous output back into input
    Given the file "previous_output.rb":
    """
    1 + 1  # => not 2
    2 + 2  # ~> Exception, something
    """
    When I run "seeing_is_believing previous_output.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 + 1  # => 2
    2 + 2  # => 4
    """

  Scenario: Printing within the file
  Scenario: Requiring other files
  Scenario: Syntactically invalid file
  Scenario: Passing a nonexistent file
  Scenario: Evaluating a file that requires other files, from a different directory
  Scenario: Passing the file on stdin
