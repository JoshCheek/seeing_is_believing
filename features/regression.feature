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


  # NOTE: Don't change the body of this file, it's nondeterministic
  # I have no idea why this particular string fucks Parser up, but other similar ones don't
  # We can probably remove this once parser reaches 2.0.0, they've fixed this bug now.
  Scenario: Parser correctly identify comments
    Given the file "parser_bug.rb" "Class # whatever"
    When I run "seeing_is_believing parser_bug.rb"
    Then stdout is "Class # whatever"
    Then stderr is empty
    And the exit status is 0


  Scenario: Modifying output doesn't fuck it up when passing it back again as input
    Given the file "modified_result.rb":
    """
    1
    # >> stdout
    2
    # !> stderr
    __END__
    """
    When I run "seeing_is_believing modified_result.rb"
    Then stdout is:
    """
    1  # => 1
    2  # => 2
    __END__
    """


  Scenario: Unintentional magic comment on not-first line
    Given the file "wtf.rb":
    """
    1
    # Transfer-Encoding: chunked
    """
    When I run "seeing_is_believing wtf.rb"
    Then stdout is:
    """
    1  # => 1
    # Transfer-Encoding: chunked
    """


  Scenario: The file contains content that looks like previous output, should not be removed
    Given the file "not_actually_previous_output.rb":
    """
    "1 # => 1"
    "2 # ~> SomeError: some message"

    "# >> some stdout"

    "# !> some stderr"
    """
    When I run "seeing_is_believing not_actually_previous_output.rb"
    Then stdout is:
    """
    "1 # => 1"                        # => "1 # => 1"
    "2 # ~> SomeError: some message"  # => "2 # ~> SomeError: some message"

    "# >> some stdout"  # => "# >> some stdout"

    "# !> some stderr"  # => "# !> some stderr"
    """


  Scenario: Multiple leading inline comments should make it through to the final program
    Given the file "multiple_leading_comments.rb":
    """
    #!/usr/bin/env ruby
    # encoding: utf-8
    'ç'
    """
    When I run "seeing_is_believing multiple_leading_comments.rb"
    Then stdout is:
    """
    #!/usr/bin/env ruby
    # encoding: utf-8
    'ç'  # => "ç"
    """
