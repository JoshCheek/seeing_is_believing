Feature: Running the binary successfully

  They say seeing is believing. So to believe that this works
  I want to execute the actual binary and look at actual results.

  It should generally record every line of code and display the results
  adjacent to the line, with output and errors displayed at the end of the file.

  Scenario: Some basic functionality
    Given the file "basic_functionality.rb":
    """
    # iteration
    5.times do |i|
      i * 2
    end

    # method and invocations
    def meth(n)
      n
    end

    meth "12"
    meth "34"

    # block style comments
    =begin
    I don't ever actually write
      comments like this
    =end

    # multilinezzz
    "a
     b"
    /a
     b/x

    <<HERE
    is a doc
    HERE

    # method invocation that occurs entirely on the next line
    [*1..10]
      .select(&:even?)
      .map { |n| n * 2 }

    # mutliple levels of nesting
    class User
      def initialize(name)
        @name = name
      end

      def name
        @name
      end
    end

    User.new("Josh").name
    User.new("Rick").name
    """
    When I run "seeing_is_believing basic_functionality.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    # iteration
    5.times do |i|  # => 5
      i * 2         # => 0, 2, 4, 6, 8
    end             # => 5

    # method and invocations
    def meth(n)
      n          # => "12", "34"
    end          # => {{method_result :meth}}

    meth "12"  # => "12"
    meth "34"  # => "34"

    # block style comments
    =begin
    I don't ever actually write
      comments like this
    =end

    # multilinezzz
    "a
     b"   # => "a\n b"
    /a
     b/x  # => /a\n b/x

    <<HERE  # => "is a doc\n"
    is a doc
    HERE

    # method invocation that occurs entirely on the next line
    [*1..10]              # => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      .select(&:even?)    # => [2, 4, 6, 8, 10]
      .map { |n| n * 2 }  # => [4, 8, 12, 16, 20]

    # mutliple levels of nesting
    class User
      def initialize(name)
        @name = name        # => "Josh", "Rick"
      end                   # => {{method_result :initialize}}

      def name
        @name   # => "Josh", "Rick"
      end       # => {{method_result :name}}
    end         # => {{method_result :name}}

    User.new("Josh").name  # => "Josh"
    User.new("Rick").name  # => "Rick"
    """

  Scenario: Passing previous output back into input
    Given the file "previous_output.rb":
    """
    1 + 1  # => not 2
    2 + 2  # ~> Exception, something


    # >> some stdout output

    # !> some stderr output

    # ~> Exception
    # ~> message
    # ~>
    # ~> backtrace
    __END__
    """
    When I run "seeing_is_believing previous_output.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 + 1  # => 2
    2 + 2  # => 4

    __END__
    """

  Scenario: Printing within the file
    Given the file "printing.rb":
    """
    print "hel"
    puts  "lo!"
    puts  ":)"
    $stderr.puts "goodbye"
    """
    When I run "seeing_is_believing printing.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    print "hel"             # => nil
    puts  "lo!"             # => nil
    puts  ":)"              # => nil
    $stderr.puts "goodbye"  # => nil

    # >> hello!
    # >> :)

    # !> goodbye
    """

  Scenario: Respects macros / magic comments
    Given the file "some_dir/uses_macros.rb":
    """
    # encoding: EUC-JP
    __FILE__
    __LINE__
    __ENCODING__
    $stdout.puts "omg"
    $stderr.puts "hi"
    DATA.read
    __LINE__
    __END__
    1
    2
    """
    When I run "seeing_is_believing some_dir/uses_macros.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    # encoding: EUC-JP
    __FILE__            # => "some_dir/uses_macros.rb"
    __LINE__            # => 3
    __ENCODING__        # => #<Encoding:EUC-JP>
    $stdout.puts "omg"  # => nil
    $stderr.puts "hi"   # => nil
    DATA.read           # => "1\n2\n"
    __LINE__            # => 8

    # >> omg

    # !> hi
    __END__
    1
    2
    """

  Scenario: Reading from stdin
    Given the stdin content "hi!"
    And the file "reads_from_stdin.rb":
    """
    puts "You said: #{gets}"
    """
    When I run "seeing_is_believing reads_from_stdin.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    puts "You said: #{gets}"  # => nil

    # >> You said: hi!
    """

  Scenario: Passing the file on stdin
    Given the stdin content "1 + 1"
    When I run "seeing_is_believing"
    Then stderr is empty
    And the exit status is 0
    And stdout is "1 + 1  # => 2"

  Scenario: Can exec another process, it records as many lines get exec'd, passes file descriptors, records exec'd output data
    Given the stdin content "pass this through"
    And the file "calls_exec.rb":
    """
    $stdout.puts "First program to stdout"
    $stderr.puts "First program to stderr"
    exec 'ruby', '-e', '
      $stdout.puts "Stdin passed to second program: #{gets.inspect}"
      $stderr.puts "Exec\'d file to stderr"
      $stdout.flush
      exec "ruby", "-v"
    '
    """
    When I run "seeing_is_believing calls_exec.rb"
    Then stderr is empty
    And stdout is:
    """
    $stdout.puts "First program to stdout"  # => nil
    $stderr.puts "First program to stderr"  # => nil
    exec 'ruby', '-e', '
      $stdout.puts "Stdin passed to second program: #{gets.inspect}"
      $stderr.puts "Exec\'d file to stderr"
      $stdout.flush
      exec "ruby", "-v"
    '

    # >> First program to stdout
    # >> Stdin passed to second program: "pass this through"
    # >> {{`ruby -v`.chomp}}

    # !> First program to stderr
    # !> Exec'd file to stderr
    """
    And the exit status is 0

  @not-windows
  Scenario: Fork records data in parent and child, parent exec does not affect it.
    Given the file "fork_exec_parent.rb":
    """
    :both
    if fork #
      :parent
      exec 'echo', 'hello'
    else
      sleep 1 #
      :child
    end
    :child

    # >> hello
    """
    When I run "seeing_is_believing fork_exec_parent.rb"
    Then stdout is:
    """
    :both                   # => :both
    if fork #
      :parent               # => :parent
      exec 'echo', 'hello'
    else
      sleep 1 #
      :child                # => :child
    end                     # => :child
    :child                  # => :child

    # >> hello
    """

  @not-windows
  Scenario: Fork records data in parent and child, child exec does not affect it.
    Given the file "fork_exec_child.rb":
    """
    :both
    if fork #
      sleep 1 #
      :parent
    else
      :child
      exec 'echo', 'hello'
    end
    :parent

    # >> hello
    """
    When I run "seeing_is_believing fork_exec_child.rb"
    Then stdout is:
    """
    :both                   # => :both
    if fork #
      sleep 1 #
      :parent               # => :parent
    else
      :child                # => :child
      exec 'echo', 'hello'
    end                     # => :parent
    :parent                 # => :parent

    # >> hello
    """


  Scenario: Implicit regexp conditional
    Given the stdin content "abc"
    And the file "implicit_regex_conditional.rb":
    """
    gets
    if /(.)c/
      $1
    end
    """
    When I run "seeing_is_believing implicit_regex_conditional.rb"
    Then stdout is:
    """
    gets       # => "abc"
    if /(.)c/  # => 1
      $1       # => "b"
    end        # => "b"
    """


  Scenario: BEGIN and END blocks
    Given the file "BEGIN_and_END.rb":
    """
    # encoding: utf-8
    p [:a, __LINE__]
    BEGIN {
      p [:b, __LINE__]
      BEGIN { p [:c, __LINE__] }
    }
    p [:d, __LINE__]
    END {
      p [:e, __LINE__]
    }
    p [:f, __LINE__]
    BEGIN { p [:g, __LINE__] }
    END { p [:h, __LINE__] }
    p [:i, __LINE__]
    "π"
    """
    When I run "seeing_is_believing BEGIN_and_END.rb"
    Then stderr is empty
    Then stdout is:
    """
    # encoding: utf-8
    p [:a, __LINE__]              # => [:a, 2]
    BEGIN {
      p [:b, __LINE__]            # => [:b, 4]
      BEGIN { p [:c, __LINE__] }  # => [:c, 5]
    }
    p [:d, __LINE__]              # => [:d, 7]
    END {
      p [:e, __LINE__]            # => [:e, 9]
    }
    p [:f, __LINE__]              # => [:f, 11]
    BEGIN { p [:g, __LINE__] }    # => [:g, 12]
    END { p [:h, __LINE__] }      # => [:h, 13]
    p [:i, __LINE__]              # => [:i, 14]
    "π"                           # => "π"

    # >> [:c, 5]
    # >> [:b, 4]
    # >> [:g, 12]
    # >> [:a, 2]
    # >> [:d, 7]
    # >> [:f, 11]
    # >> [:i, 14]
    # >> [:h, 13]
    # >> [:e, 9]
    """
    When I run "seeing_is_believing BEGIN_and_END.rb --xmpfilter-style"
    Then stderr is empty
    Then stdout is:
    """
    # encoding: utf-8
    p [:a, __LINE__]
    BEGIN {
      p [:b, __LINE__]
      BEGIN { p [:c, __LINE__] }
    }
    p [:d, __LINE__]
    END {
      p [:e, __LINE__]
    }
    p [:f, __LINE__]
    BEGIN { p [:g, __LINE__] }
    END { p [:h, __LINE__] }
    p [:i, __LINE__]
    "π"

    # >> [:c, 5]
    # >> [:b, 4]
    # >> [:g, 12]
    # >> [:a, 2]
    # >> [:d, 7]
    # >> [:f, 11]
    # >> [:i, 14]
    # >> [:h, 13]
    # >> [:e, 9]
    """
