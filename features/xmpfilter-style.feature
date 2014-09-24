@xmpfilter
Feature: Xmpfilter style
  Support the same (or highly similar) interface as xmpfilter,
  so that people who use that lib can easily transition to SiB.


  Scenario: --xmpfilter-style Generic updating of marked lines
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
    Given the file "xmpfilter-prev-line1.rb":
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
    When I run "seeing_is_believing --xmpfilter-style xmpfilter-prev-line1.rb"
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

  Scenario: --xmpfilter-style overrides previous multiline results
    Given the file "xmpfilter-prev-line2.rb":
    """
    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter-prev-line2.rb | seeing_is_believing --xmpfilter-style"
    Then stdout is:
    """
    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # => {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
    """


  Scenario: --xmpfilter-style respects the line formatting (but not currently alignment strategies, it just preserves submitted alignment)
    Given the file "xmpfilter_line_lengths.rb":
    """
    '1' * 30 # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style --line-length 19 xmpfilter_line_lengths.rb"
    Then stdout is:
    """
    '1' * 30 # => "1...
    # => "1111111111...
    """


    @josh1
  Scenario: Errors on annotated lines
    Given the file "xmpfilter_error_on_annotated_line.rb":
    """
    raise "omg" # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter_error_on_annotated_line.rb"
    Then stderr is empty
    And the exit status is 1
    Then stdout is:
    """
    raise "omg" # => # ~> RuntimeError: ZOMG\n!!!!

    # ~> RuntimeError
    # ~> omg
    # ~>
    # ~> xmpfilter_error_on_annotated_line.rb:1:in `<main>'
    """


    @josh2
  Scenario: Errors on unannotated lines
    Given the file "xmpfilter_error_on_annotated_line.rb":
    """
    raise "omg"
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter_error_on_annotated_line.rb"
    Then stderr is empty
    And the exit status is 1
    Then stdout is:
    """
    raise "omg" # =>
    """


  Scenario: pp output on line with exception


  Scenario: Cleaning previous output
    Given the file "xmpfilter_cleaning.rb":
    """
    1 # => "1...
    # => "1111111111...
    #    "1111111111...
    # normal comment
    # => 123
    """
    When I run "seeing_is_believing --xmpfilter-style --clean xmpfilter_cleaning.rb"
    Then stdout is:
    """
    1
    # normal comment
    """
