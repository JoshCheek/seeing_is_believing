Feature: Running in safe-mode

  It would be nice to be able to expose SiB via a bot like hubot.
  To do this, though, you need to be able to trust the code that users submit.
  I wrote https://github.com/JoshCheek/eval_in to use the https://eval.in
  website to run code safely. SiB just needs to use it.

  Scenario: Running normal code
    Given the file 'safe-example1.rb' 'print "hello, #{gets}"'
    And the stdin content "world"
    When I run "seeing_is_believing --safe safe-example1.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    print "hello, #{gets}"  # => nil

    # >> hello, world
    """

  Scenario: Unsafe code
  Scenario: With --xmpfilter
  Scenario: With incompatible options
  Scenario: With --timeout
  Scenario: With --as
  Scenario: With --debug
  Scenario: Wpper-bound number of captures to prevent it from consuming too many resources
    --program program         # Pass the program to execute as an argument
    --load-path dir           # a dir that should be added to the $LOAD_PATH
    --require file            # additional files to be required before running the program
    --encoding encoding       # sets file encoding, equivalent to Ruby's -Kx (see `man ruby` for valid values)
