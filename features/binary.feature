Feature: Running the binary
  They say seeing is believing. So to believe that this works
  I want to see that it works by making a binary to use the lib.

  It should be approximately like xmpfilter, except that it should
  run against every line.

  Scenario: Some basic functionality
    Given the file "f.rb":
    """
    a = '12'
    a + a

    5.times do |i|
      i * 2
    end
    """
    When I run "seeing_is_believing f.rb"
    And stderr is empty
    Then the exit status is 0
    And stdout is:
    """
    a = '12'        # => "12"
    a + a           # => "1212"

    5.times do |i|
      i * 2         # => 0, 2, 4, 6, 8
    end             # => 5

    """

  Scenario: Printing within the file
  Scenario: Raising exceptions
  Scenario: Requiring other files
  Scenario: Syntactically invalid file
