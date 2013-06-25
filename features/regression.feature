Feature:
  In order to not fix the same shit over and over again
  As the dev who wrote SeeingIsBelieving
  I want to have tests on those bugs that I found and could not have predicted

  Scenario: A program containing a single comment
    Given the stdin content "# single comment"
    When I run "seeing_is_believing"
    Then stderr is empty
    And the exit status is 0
    And stdout is "# single comment"

  Scenario: Name error just fucks everything
    Given the file "no_method_error.rb":
    """
    a
    """
    When I run "seeing_is_believing no_method_error.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout is:
    """
    a  # ~> NameError: undefined local variable or method `a' for main:Object
    """

  Scenario: Errors being raised in the evaluated code that don't exist in the evaluating code
    Given the file "raising_custom_errors.rb":
    """
    MyError = Class.new StandardError
    begin
      raise "a"
    rescue
      raise MyError.new("c")
    end
    """
    When I run "seeing_is_believing raising_custom_errors.rb"
    Then stderr is empty
    And the exit status is 1

  Scenario: statements that inherit void value expressions
    Given the file "statements_that_inherit_void_value_expressions.rb":
    """
    def m
      if true
        return 1
      end
    end
    m
    """
    When I run "seeing_is_believing statements_that_inherit_void_value_expressions.rb"
    Then stderr is empty
    And the exit status is 0
    Then stdout is:
    """
    def m
      if true
        return 1
      end
    end           # => nil
    m             # => 1
    """

  Scenario: comments aren't updated with values
    Given the file "comments_arent_updated_with_values.rb":
    """
    1 # some comment
    2 # some other comment
    """
    When I run "seeing_is_believing comments_arent_updated_with_values.rb"
    Then stdout is:
    """
    1 # some comment
    2 # some other comment
    """

