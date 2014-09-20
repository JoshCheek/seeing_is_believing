@xmpfilter
Feature: Xmpfilter style
  Support the same (or highly similar) interface as xmpfilter,
  so that people who use that lib can easily transition to SiB.


  Scenario: --xmpfilter-style
    Given the file "magic_comments.rb":
    """
    1+1# =>
    2+2    # => 10
    "a
     b" # =>
    /a
     b/ # =>
    1
    "omg"
    # =>
    "omg2"
    # => "not omg2"
    """
    When I run "seeing_is_believing --xmpfilter-style magic_comments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1+1# => 2
    2+2    # => 4
    "a
     b" # => "a\n b"
    /a
     b/ # => /a\n b/
    1
    "omg"
    # => "omg"
    "omg2"
    # => "omg2"
    """


  Scenario: --xmpfilter-style uses pp to inspect annotations whose value comes from the previous line (#44)
    Given the file "xmpfilter-prev-line.rb":
    """
    { foo: 42,
      bar: {
        baz: 1,
        buz: 2,
        fuz: 3,
      },
      wibble: {
        magic_word: "xyzzy",
      }
    } # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter-prev-line.rb"
    Then stdout is:
    """
    { foo: 42,
      bar: {
        baz: 1,
        buz: 2,
        fuz: 3,
      },
      wibble: {
        magic_word: "xyzzy",
      }
    } # => {:foo=>42, :bar=>{:baz=>1, :buz=>2, :fuz=>3}, :wibble=>{:magic_word=>"xyzzy"}}
    # => {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter-prev-line.rb | seeing_is_believing --xmpfilter-style"
    Then stdout is:
    """
    { foo: 42,
      bar: {
        baz: 1,
        buz: 2,
        fuz: 3,
      },
      wibble: {
        magic_word: "xyzzy",
      }
    } # => {:foo=>42, :bar=>{:baz=>1, :buz=>2, :fuz=>3}, :wibble=>{:magic_word=>"xyzzy"}}
    # => {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
    """


  Scenario: --xmpfilter-style respects the line formatting (but not currently alignment strategies, it just preserves submitted alignment)
    Given the file "line_lengths3.rb":
    """
    '1' * 30 # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style --line-length 19 line_lengths3.rb"
    Then stdout is:
    """
    '1' * 30 # => "1...
    # => "1111111111...
    """
