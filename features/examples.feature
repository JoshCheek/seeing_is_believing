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
    end

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

  Scenario: Respects macros
    Given the file "some_dir/uses_macros.rb":
    """
    # encoding: utf-8
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
    # encoding: utf-8
    __FILE__            # => "some_dir/uses_macros.rb"
    __LINE__            # => 3
    __ENCODING__        # => #<Encoding:UTF-8>
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

  Scenario: Execing another process
    # Print tons of x's b/c it reads more data in than it needs.
    # No obvious way to turn it off, but doesn't matter,
    # we just want to show that the file descriptors make it through the execs
    Given the stdin content "{{['x']*10_000*"\n"}}"
    And the file "calls_exec.rb":
    """
    $stdout.puts "Line 1: #{gets.inspect}"
    $stderr.puts "calls_exec to stderr"
    exec 'ruby', '-e', '
      $stdout.puts "Line 2: #{gets.inspect}"
      $stderr.puts "exec\'d file to stderr"
      $stdout.flush
      exec "ruby", "-v"
    '
    """
    When I run "seeing_is_believing calls_exec.rb"
    Then stderr is empty
    And stdout is:
    """
    $stdout.puts "Line 1: #{gets.inspect}"  # => nil
    $stderr.puts "calls_exec to stderr"     # => nil
    exec 'ruby', '-e', '
      $stdout.puts "Line 2: #{gets.inspect}"
      $stderr.puts "exec\'d file to stderr"
      $stdout.flush
      exec "ruby", "-v"
    '

    # >> Line 1: "x\n"
    # >> Line 2: "x\n"
    # >> {{`ruby -v`.chomp}}

    # !> calls_exec to stderr
    # !> exec'd file to stderr
    """
    And the exit status is 0
