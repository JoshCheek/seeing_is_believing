Feature: Running the binary unsuccessfully

  Sometimes I mess up and use the program in a way that doesn't work.
  I'd like it to be helpful in these situations so I can fix my use.

  # show that it displays next to the first place in the file
  # and should maybe print the stacktrace at the bottom
  Scenario: Raising exceptions
    Given the file "raises_exception.rb":
    """
    raise "ZOMG\n!!!!"
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
    end                # => {{method_result :first_defined}}

    def second_defined
      require_relative 'raises_exception'  # ~> RuntimeError: ZOMG\n!!!!
    end                                    # => {{method_result :second_defined}}

    first_defined

    # ~> RuntimeError
    # ~> ZOMG
    # ~> !!!!
    # ~>
    # ~> {{Haiti.config.proving_grounds_dir}}/raises_exception.rb:1:in `<top (required)>'
    # ~> requires_exception_raising_code.rb:6:in `require_relative'
    # ~> requires_exception_raising_code.rb:6:in `second_defined'
    # ~> requires_exception_raising_code.rb:2:in `first_defined'
    # ~> requires_exception_raising_code.rb:9:in `<main>'
    """

  @not-windows
  Scenario: Raising multiple exceptions
    Given the file "multiple_exceptions.rb":
    """
    if pid = fork #
      Process.wait pid #
      raise "parent"
    else
      raise "child"
    end

    """
    When I run "seeing_is_believing multiple_exceptions.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout is:
    """
    if pid = fork #
      Process.wait pid #
      raise "parent"  # ~> RuntimeError: parent
    else
      raise "child"   # ~> RuntimeError: child
    end

    # ~> RuntimeError
    # ~> child
    # ~>
    # ~> multiple_exceptions.rb:5:in `<main>'

    # ~> RuntimeError
    # ~> parent
    # ~>
    # ~> multiple_exceptions.rb:3:in `<main>'
    """
    When I run "seeing_is_believing multiple_exceptions.rb -x"
    Then stderr is empty
    And the exit status is 1
    And stdout is:
    """
    if pid = fork #
      Process.wait pid #
      raise "parent" # ~> RuntimeError: parent
    else
      raise "child" # ~> RuntimeError: child
    end

    # ~> RuntimeError
    # ~> child
    # ~>
    # ~> multiple_exceptions.rb:5:in `<main>'

    # ~> RuntimeError
    # ~> parent
    # ~>
    # ~> multiple_exceptions.rb:3:in `<main>'
    """

  Scenario: Syntactically invalid file
    Given the file "invalid_syntax.rb":
    """
    'this is valid'
    'this is not
    """
    When I run "seeing_is_believing invalid_syntax.rb"
    Then stderr is:
    """
    Syntax Error: invalid_syntax.rb:2
    unterminated string meets end of file
    """
    And the exit status is 2
    And stdout is empty

  Scenario: Passing a nonexistent file
    When I run "seeing_is_believing this_file_does_not_exist.rb"
    Then stderr is "Error: this_file_does_not_exist.rb does not exist!"
    And the exit status is 2
    And stdout is empty

  Scenario: Passing unknown flags
    Given the file "some_file" "1"
    When I run "seeing_is_believing --unknown-flag"
    Then stderr is 'Error: --unknown-flag is not a flag, see the help screen (-h) for a list of options'
    And the exit status is 2
    And stdout is empty

  Scenario: Reports deprecations with errors
    When I run "seeing_is_believing this_file_does_not_exist.rb --number-of-captures 10"
    Then stderr includes "--number-of-captures 10"
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
    And stdout includes:
    """
    def m() m end  # ~> SystemStackError: stack level too deep
    m
    """
