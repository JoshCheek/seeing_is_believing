Feature:
  In order to not fix the same shit over and over again
  As the dev who wrote SeeingIsBelieving
  I want to have tests on those bugs that I found and could not have predicted

  Scenario: No method error just fucks everything
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
