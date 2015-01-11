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

    # ~> NameError
    # ~> undefined local variable or method `a' for main:Object
    # ~>
    # ~> no_method_error.rb:1:in `<main>'
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
      if true     # => true
        return 1  # => 1
      end
    end           # => {{method_result :m}}
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
    Then stdout is exactly:
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


  Scenario: Some strings look like comments
    Given the file "strings_that_look_like_comments.rb":
    """
    "1
     #{2}"
    """
    When I run "seeing_is_believing strings_that_look_like_comments.rb"
    Then stdout is:
    """
    "1
     #{2}"  # => "1\n 2"
    """


  Scenario: Kori's bug (Issue #11)
    Given the file "koris_bug.rb":
    """
    class CreditCard

    end

    describe CreditCard do

    end
    """
    When I run "seeing_is_believing koris_bug.rb"
    Then stdout is:
    """
    class CreditCard

    end

    describe CreditCard do  # ~> NoMethodError: undefined method `describe' for main:Object

    end

    # ~> NoMethodError
    # ~> undefined method `describe' for main:Object
    # ~>
    # ~> koris_bug.rb:5:in `<main>'
    """


  Scenario: lambda-style fibonacci generator
    Given the file "lambda_style_fib_gen.rb":
    """
    class Proc
      def inspect
        "<PROC>"
      end
    end

    generic_fib_gen = -> current, prev {
      -> {
        [(current+prev), generic_fib_gen.(current+prev, current)]
      }
    }

    fib_gen    = generic_fib_gen.(1, -1)
    n, fib_gen = fib_gen.()
    n, fib_gen = fib_gen.()
    n, fib_gen = fib_gen.()
    """
    When I run "seeing_is_believing lambda_style_fib_gen.rb"
    Then stdout is:
    """
    class Proc
      def inspect
        "<PROC>"   # => "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>", "<PROC>"
      end          # => {{method_result :inspect}}
    end

    generic_fib_gen = -> current, prev {
      -> {
        [(current+prev), generic_fib_gen.(current+prev, current)]  # => [0, <PROC>], [1, <PROC>], [1, <PROC>]
      }                                                            # => <PROC>, <PROC>, <PROC>, <PROC>
    }                                                              # => <PROC>

    fib_gen    = generic_fib_gen.(1, -1)  # => <PROC>
    n, fib_gen = fib_gen.()               # => [0, <PROC>]
    n, fib_gen = fib_gen.()               # => [1, <PROC>]
    n, fib_gen = fib_gen.()               # => [1, <PROC>]
    """


  Scenario: Repeated invocations
    When I run "echo 'puts 1' | seeing_is_believing | seeing_is_believing"
    Then stdout is:
    """
    puts 1  # => nil

    # >> 1
    """


  Scenario: Heredoc at the end test
    Given the file "heredoc_at_the_end.rb":
    """
    puts(<<A)
    omg
    A
    """
    When I run "seeing_is_believing heredoc_at_the_end.rb"
    Then stdout is:
    """
    puts(<<A)  # => nil
    omg
    A

    # >> omg
    """


  Scenario: Long DATA segment in a valid file
    Given the file "long_valid_data_segment.rb":
    """
    __END__
    {{'.' * 100_000}}
    """
    When I run "seeing_is_believing long_valid_data_segment.rb"
    Then stderr is empty
    Then stdout is:
    """
    __END__
    {{'.' * 100_000}}
    """


  Scenario: Long DATA segment in an invalid file
    Given the file "long_invalid_data_segment.rb":
    """
    '
    __END__
    {{'.' * 100_000}}
    """
    When I run "seeing_is_believing long_invalid_data_segment.rb"
    Then stderr includes "1: unterminated string meets end of file"
    And the exit status is 2
    And stdout is empty


  Scenario: A program using system
    Given the file "invoking_system.rb":
    """
    system %(ruby -e '$stdout.puts %(hello)')
    system %(ruby -e '$stderr.puts %(world)')
    """
    When I run "seeing_is_believing invoking_system.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    system %(ruby -e '$stdout.puts %(hello)')  # => true
    system %(ruby -e '$stderr.puts %(world)')  # => true

    # >> hello

    # !> world
    """


  Scenario: A program overriding stdout/stderr
    Given the file "black_hole.rb":
    """
    File.open '/dev/null', 'w' do |black_hole|
      STDERR = $stderr = black_hole
      STDOUT = $stdout = black_hole
      puts "You won't see this, it goes into the black hole"
      system %q(ruby -e '$stdout.puts "stdout gets past it b/c of dumb ruby bug"')
      system %q(ruby -e '$stderr.puts "stderr gets past it b/c of dumb ruby bug"')
    end
    """
    When I run "seeing_is_believing black_hole.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    File.open '/dev/null', 'w' do |black_hole|                                      # => File
      STDERR = $stderr = black_hole                                                 # => #<File:/dev/null>
      STDOUT = $stdout = black_hole                                                 # => #<File:/dev/null>
      puts "You won't see this, it goes into the black hole"                        # => nil
      system %q(ruby -e '$stdout.puts "stdout gets past it b/c of dumb ruby bug"')  # => true
      system %q(ruby -e '$stderr.puts "stderr gets past it b/c of dumb ruby bug"')  # => true
    end                                                                             # => true

    # >> stdout gets past it b/c of dumb ruby bug

    # !> stderr gets past it b/c of dumb ruby bug
    """


  Scenario: Incorrect wrapping in some programs
    Given the file "incorrect_wrapping.rb":
    """
    a
    class B
      def c
        d = 1
      end
    end
    """
    When I run "seeing_is_believing incorrect_wrapping.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout is:
    """
    a          # ~> NameError: undefined local variable or method `a' for main:Object
    class B
      def c
        d = 1
      end
    end

    # ~> NameError
    # ~> undefined local variable or method `a' for main:Object
    # ~>
    # ~> incorrect_wrapping.rb:1:in `<main>'
    """


  Scenario: Can deal with hostile environments
    Given the file "bang_object.rb":
    """
    class Object
      def !(a)
      end
    end
    """
    When I run "seeing_is_believing bang_object.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    class Object
      def !(a)
      end         # => {{method_result :!}}
    end
    """


  Scenario: Is cool with exceptions raised in at_exit hooks
    Given the file "at_exit_exception_direct.rb" "at_exit { raise 'zomg' }"
    When I run "seeing_is_believing at_exit_exception_direct.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout includes "at_exit { raise 'zomg' }  # ~>"
    And stdout includes "RuntimeError"
    And stdout includes "zomg"
    And stdout does not include "the_matrix"


  Scenario: Is cool with exceptions raised in at_exit exceptions by code not in the running file (e.g. SimpleCov)
    Given the file "at_exit_exception_indirect1.rb" "at_exit { raise 'zomg' }"
    Given the file "at_exit_exception_indirect2.rb" "require_relative 'at_exit_exception_indirect1'"
    When I run "seeing_is_believing at_exit_exception_indirect2.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout includes "require_relative 'at_exit_exception_indirect1'  # => true"
    And stdout includes "RuntimeError"
    And stdout includes "zomg"


  Scenario: Comments with makers elsewhere in them
    Given the file "comments_with_markers_elsewhere.rb":
    """
    # a # => a
    """
    When I run "seeing_is_believing comments_with_markers_elsewhere.rb"
    Then stdout is:
    """
    # a # => a
    """


  Scenario: Deadlocked
    Given the file "deadlocked.rb":
    """
    require 'thread'
    Thread.new { Queue.new.shift }.join
    """
    When I run "seeing_is_believing deadlocked.rb"
    Then stdout includes:
    """
    require 'thread'                     # => false
    Thread.new { Queue.new.shift }.join  # ~> fatal
    """


  Scenario: Xmpfilter does not write the error messages inside of strings
    Given the file "error_within_string.rb":
    """
    1.send "a
    b"
    """
    When I run "seeing_is_believing --xmpfilter-style error_within_string.rb"
    Then stdout includes:
    """
    1.send "a
    b"

    # ~> NoMethodError
    # ~> undefined method `a
    # ~> b' for 1:Fixnum
    """


  # not going to get too detailed on what it prints, b/c that message seems pretty fragile,
  # but just generally that it doesn't fkn blow up
  Scenario: https://github.com/JoshCheek/seeing_is_believing/issues/46
    Given the file "json_and_encodings.rb":
    """
    # encoding: utf-8
    require 'json'
    JSON.parse JSON.dump("√")
    """
    When I run "seeing_is_believing json_and_encodings.rb"
    Then stderr is empty
    And the exit status is 1
    And stdout includes:
    """
    require 'json'             # => true
    JSON.parse JSON.dump("√")
    """
