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

    end  # => nil

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
    end            # => {{method_result :inspect}}

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
    When I run the pipeline "echo puts 1" | "seeing_is_believing" | "seeing_is_believing"
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
    Then stderr is:
    """
    Syntax Error: long_invalid_data_segment.rb:1
    unterminated string meets end of file
    """
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
    require 'rubygems'
    File.open IO::NULL, 'w' do |black_hole|
      STDERR = $stderr = black_hole; nil
      STDOUT = $stdout = black_hole; nil
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
    require 'rubygems'                                                              # => false
    File.open IO::NULL, 'w' do |black_hole|                                         # => File
      STDERR = $stderr = black_hole; nil                                            # => nil
      STDOUT = $stdout = black_hole; nil                                            # => nil
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
    end           # => {{method_result :!}}
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


  Scenario: Comments with markers elsewhere in them
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
    # ~> undefined method
    """


  # See this issue for the issue we're testing for: https://github.com/JoshCheek/seeing_is_believing/issues/46
  # See this issue for why we turn it off on 2.4: https://github.com/flori/json/issues/309
  #
  # Not going to get too detailed on what it prints, b/c that message seems pretty fragile,
  # but just generally that it doesn't fkn blow up
  @not-2.4
  @not-2.5
  Scenario: Old JSON bug
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


  # https://github.com/JoshCheek/seeing_is_believing/wiki/Encodings
  # https://github.com/JoshCheek/seeing_is_believing/issues/109
  Scenario: Assumes utf-8 for files regardless of what Ruby thinks
    Given the environment variable "LANG" is set to ''
    And the file "utf8_file_without_magic_comment.rb" "縧 = 1"
    When I run "seeing_is_believing utf8_file_without_magic_comment.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is "縧 = 1  # => 1"


  # https://github.com/JoshCheek/seeing_is_believing/issues/109
  Scenario: Assumes utf-8 for files regardless of what Ruby thinks
    Given the environment variable "LANG" is set to ''
    Given the stdin content "縧 = 1"
    When I run "seeing_is_believing utf8_file_without_magic_comment.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is "縧 = 1  # => 1"


  Scenario: Correctly identify end of file
    Given the file "fake_data_segment.rb":
    """
    puts "output"
    "
    __END__
    "
    __END__
    """
    When I run "seeing_is_believing fake_data_segment.rb"
    Then stdout is:
    """
    puts "output"  # => nil
    "
    __END__
    "              # => "\n__END__\n"

    # >> output
    __END__
    """

  @not-implemented
  Scenario: Interpolating in a heredoc and walking backwards with xmpfilter style to figure out which expression to record (#83)
    Given the file "heredoc_woes.rb":
    """
    <<-HERE # =>
    1#{1+1}3
    HERE
    # =>
    """
    When I run "seeing_is_believing -x heredoc_woes.rb"
    Then stdout is:
    """
    <<-HERE # => "123\n"
    1#{1+1}3
    HERE
    # => "123\n"
    """

  @not-2.0.0
  Scenario: Executing correctly in a hostile world
    Given the file "hostile_world.rb":
    """
    # SiB works, but Ruby will explode while trying to make the exception
    # if we do it later, so we'll make it up here
    zde = (1/0 rescue $!)

    class Hash
      undef []
      undef []=
      undef fetch
    end
    class IO
      undef sync
      undef <<
      undef flush
      undef puts
      undef close
    end
    class Queue
      undef <<
      undef shift
      undef clear
    end
    class Symbol
      undef ==
      undef to_s
      undef inspect
    end
    class String
      undef ==
      undef to_s
      undef to_str
      undef inspect
      undef to_i
    end
    class Fixnum
      undef <
      undef <<
      undef ==
      def next # "redefining instead of undefing b/c it comes from Integer"
      end
      undef to_s
      undef inspect
    end
    class Array
      undef pack
      undef <<
      undef to_ary
      undef grep
      undef first
      undef []
      undef []=
      undef each
      undef map
      undef join
      undef size
      undef to_s
    end
    class << Marshal
      undef dump
      undef load
    end
    module Kernel
      undef kind_of?
      undef block_given?
    end
    module Enumerable
      undef map
    end
    class SystemExit
      undef status
    end
    class Exception
      undef message
      # undef backtrace # https://bugs.ruby-lang.org/issues/12925
      def class
        "totally the wrong thing"
      end
    end
    class << Thread
      undef new
      undef current
    end
    class Thread
      undef join
      undef abort_on_exception
    end
    class Class
      undef new
      undef allocate
      undef singleton_class
      undef class_eval
    end
    class BasicObject
      undef initialize
    end
    class Module
      undef ===
      undef define_method
      undef instance_method
    end
    class UnboundMethod
      undef bind
    end
    class Method
      undef call
    end
    class Proc
      undef call
      undef to_proc
    end
    class NilClass
      undef to_s
    end

    # ---

    class Zomg
    end

    Zomg                       # =>
    class << Zomg
      attr_accessor :inspect
    end
    Zomg.inspect = "lolol"
    Zomg                       # =>
    raise zde
    """
    When I run "seeing_is_believing -x hostile_world.rb"
    Then stdout includes 'Zomg                       # => Zomg'
    And  stdout includes 'Zomg                       # => lolol'
    And  stdout includes '# ~> ZeroDivisionError'
    And  stdout includes '# ~> divided by 0'


  Scenario: All objects have an object id (Issue #91)
    Given the file "object_ids.rb":
    """
    ObjectSpace.each_object { |o| o.object_id || p(obj: o) }#
    """
    When I run "seeing_is_believing object_ids.rb"
    Then stderr is empty
    And stdout is:
    """
    ObjectSpace.each_object { |o| o.object_id || p(obj: o) }#
    """


  Scenario: Does not blow up when the program closes its stdin/stdout/stderr
    Given the stdin content "input"
    And the file "closed_pipes.rb":
    """
    [$stdin, $stdout, $stderr].each &:close#
    """
    When I run "seeing_is_believing closed_pipes.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    [$stdin, $stdout, $stderr].each &:close#
    """


  Scenario: Overriding Symbol#inspect
    Given the file "overriding_symbol_inspect.rb":
    """
    :abc # =>
    class Symbol
      def inspect
        "overridden"
      end
    end
    :abc # =>
    """
    When I run "seeing_is_believing overriding_symbol_inspect.rb -x"
    Then stderr is empty
    And the exit status is 0
    Then stdout is:
    """
    :abc # => :abc
    class Symbol
      def inspect
        "overridden"
      end
    end
    :abc # => overridden
    """


  Scenario: SiB running SiB
    Given the file "sib_running_sib.rb":
    """
    require 'seeing_is_believing'
    SeeingIsBelieving.call("1+1").result[1][0]
    """
    When I run "seeing_is_believing sib_running_sib.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    require 'seeing_is_believing'               # => true
    SeeingIsBelieving.call("1+1").result[1][0]  # => "2"
    """


  Scenario: Errors should not blow away comments (Issue #120)
    Given the file "sib_with_error_on_uncommented_line.rb" "dne"
    And   the file "sib_with_error_on_commented_line.rb" "dne # this doesn't exist!"
    When I run "seeing_is_believing -x sib_with_error_on_uncommented_line.rb"
    Then stdout is:
    """
    dne # ~> NameError: undefined local variable or method `dne' for main:Object

    # ~> NameError
    # ~> undefined local variable or method `dne' for main:Object
    # ~>
    # ~> sib_with_error_on_uncommented_line.rb:1:in `<main>'
    """
    When I run "seeing_is_believing -x sib_with_error_on_commented_line.rb"
    Then stdout is:
    """
    dne # this doesn't exist!

    # ~> NameError
    # ~> undefined local variable or method `dne' for main:Object
    # ~>
    # ~> sib_with_error_on_commented_line.rb:1:in `<main>'
    """
    When I run "seeing_is_believing sib_with_error_on_uncommented_line.rb"
    Then stdout is:
    """
    dne  # ~> NameError: undefined local variable or method `dne' for main:Object

    # ~> NameError
    # ~> undefined local variable or method `dne' for main:Object
    # ~>
    # ~> sib_with_error_on_uncommented_line.rb:1:in `<main>'
    """
    When I run "seeing_is_believing sib_with_error_on_commented_line.rb"
    Then stdout is:
    """
    dne # this doesn't exist!

    # ~> NameError
    # ~> undefined local variable or method `dne' for main:Object
    # ~>
    # ~> sib_with_error_on_commented_line.rb:1:in `<main>'
    """


  Scenario: Errors on files read from stdin with --local-cwd are matched to the correct lines
    Given the file "local_cwd_and_error_on_uncommented_line.rb" "dne"
    When I run "seeing_is_believing --local-cwd < local_cwd_and_error_on_uncommented_line.rb"
    Then stdout includes "dne  # ~> NameError: undefined local variable or method `dne' for main:Object"


  Scenario: Inspects strings even when they have a singleton class (Issue #118)
    Given the file "result_of_inspect_has_a_singleton_class.rb":
    """
    str = "a string"
    def str.inspect
      self
    end
    str  # =>
    """
    When I run "seeing_is_believing -x result_of_inspect_has_a_singleton_class.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    str = "a string"
    def str.inspect
      self
    end
    str  # => a string
    """


  Scenario: The last line can end in a semicolon
    When I run "seeing_is_believing -e '1'"
    Then stdout is "1  # => 1"
    When I run "seeing_is_believing -e '1;'"
    Then stdout is "1;  # => 1"


  Scenario: A spy / proxy class (Issue #136)
    Given the file "spy_class.rb":
    """
    class String
      def self.===(obj)
        true
      end
    end
    class Spy < BasicObject
      def method_missing(name, *args, &block)
        self
      end
    end
    Spy.new  # =>
    """
    When I run "seeing_is_believing -x spy_class.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout includes "Spy.new  # => #<Spy:"


  Scenario: Refined inspect
    Given the file "refined_inspect.rb":
    """
    module Humanize
      refine Float do
        def inspect
          rounded = "%.2f" % self
          rounded.reverse!
          rounded.gsub! /(\d{3})/, '\1,'
          rounded.chomp! ","
          rounded.reverse!
          rounded
        end #
      end
    end
    using Humanize
    12345.6789  # =>
    """
    When I run "seeing_is_believing refined_inspect.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    module Humanize
      refine Float do
        def inspect
          rounded = "%.2f" % self         # => "12345.68"
          rounded.reverse!                # => "86.54321"
          rounded.gsub! /(\d{3})/, '\1,'  # => "86.543,21"
          rounded.chomp! ","              # => nil
          rounded.reverse!                # => "12,345.68"
          rounded                         # => "12,345.68"
        end #
      end                                 # => #<refinement:Float@Humanize>
    end                                   # => #<refinement:Float@Humanize>
    using Humanize                        # => main
    12345.6789                            # => 12,345.68
    """
    When I run "seeing_is_believing refined_inspect.rb -x"
    Then stderr is empty
    And the exit status is 0
    Then stdout is:
    """
    module Humanize
      refine Float do
        def inspect
          rounded = "%.2f" % self
          rounded.reverse!
          rounded.gsub! /(\d{3})/, '\1,'
          rounded.chomp! ","
          rounded.reverse!
          rounded
        end #
      end
    end
    using Humanize
    12345.6789  # => 12,345.68
    """
