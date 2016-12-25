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
    3+3#=>
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
    3+3# => 6
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

  Scenario: --xmpfilter-style, when displayed on the next line, prints the string across multiple lines
    Given the file "xmpfilter-prev-line-is-multiline-string.rb":
    """
    "0123456789\nabcdefghij\n0123456789\n0123456789\n0123456789\n0123456789\n" # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter-prev-line-is-multiline-string.rb"
    Then stdout is:
    """
    "0123456789\nabcdefghij\n0123456789\n0123456789\n0123456789\n0123456789\n" # => "0123456789\nabcdefghij\n0123456789\n0123456789\n0123456789\n0123456789\n"
    # => "0123456789\n" +
    #    "abcdefghij\n" +
    #    "0123456789\n" +
    #    "0123456789\n" +
    #    "0123456789\n" +
    #    "0123456789\n"
    """


  Scenario: --xmpfilter-style overrides previous multiline results
    Given the file "xmpfilter-prev-line2.rb":
    """
    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # =>
    """
    When I run the pipeline "seeing_is_believing --xmpfilter-style xmpfilter-prev-line2.rb" | "seeing_is_believing --xmpfilter-style"
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


  Scenario: Errors on annotated lines
    Given the file "xmpfilter_error_on_annotated_line.rb":
    """
    raise "ZOMG\n!!!!" # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter_error_on_annotated_line.rb"
    Then stderr is empty
    And the exit status is 1
    Then stdout is:
    """
    raise "ZOMG\n!!!!" # => RuntimeError: ZOMG\n!!!!

    # ~> RuntimeError
    # ~> ZOMG
    # ~> !!!!
    # ~>
    # ~> xmpfilter_error_on_annotated_line.rb:1:in `<main>'
    """


  Scenario: Errors on unannotated lines
    Given the file "xmpfilter_error_on_unannotated_line.rb":
    """
    raise "ZOMG\n!!!!"
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter_error_on_unannotated_line.rb"
    Then stderr is empty
    And the exit status is 1
    Then stdout is:
    """
    raise "ZOMG\n!!!!" # ~> RuntimeError: ZOMG\n!!!!

    # ~> RuntimeError
    # ~> ZOMG
    # ~> !!!!
    # ~>
    # ~> xmpfilter_error_on_unannotated_line.rb:1:in `<main>'
    """


  Scenario: Cleaning previous output does not clean the xmpfilter annotations
    Given the file "xmpfilter_cleaning.rb":
    """
    # commented out # => previous annotation
    1 # => "1...
    # => "1111111111...
    #    "1111111111...
    # normal comment

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # => {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
    """
    When I run "seeing_is_believing --xmpfilter-style --clean xmpfilter_cleaning.rb"
    Then stdout is:
    """
    # commented out # => previous annotation
    1 # =>
    # =>
    # normal comment

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # =>
    """


  # Not totally in love with this, but it'll do unless I can think of something better.
  Scenario: Error raised on an annotated line preserves the annotation
    Given the file "error_on_annotated_line.a.rb":
    """
    "a"+1 # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style error_on_annotated_line.a.rb"
    Then stdout includes:
    """
    "a"+1 # => TypeError:
    """
    And stdout includes:
    """
    # =>

    # ~> TypeError
    """
    Given the file "error_on_annotated_line.b.rb":
    """
    "a"+"1" # => TypeError: no implicit conversion of Fixnum into String
    # =>

    # ~> TypeError
    # ~> no implicit conversion of Fixnum into String
    """
    When I run "seeing_is_believing --xmpfilter-style error_on_annotated_line.b.rb"
    Then stdout is:
    """
    "a"+"1" # => "a1"
    # => "a1"
    """


  # maybe can't fix this as it depends on the implementation of PP.pp
  @not-implemented
  Scenario: It can record values even when method is overridden
    Given the file "pretty_inspect_with_method_overridden.rb":
    """
    def method()end; self # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style pretty_inspect_with_method_overridden.rb"
    Then stdout is:
    """
    def method()end; self # => main
    # => main
    """


  # Choosing this output style b/c it's what xmpfilter chooses,
  # and it works conveniently with what's already in place.
  #
  # It looks better with the comma on the preceding line, but harder to identify the individual results.
  #
  # It looks better with an empty line between the results, but if the user strips trailing whitespace inbetween runs,
  # it will confuse the annotations for normal comments.
  #
  # Might be cool to have it do a value comment before each result, instead of a comma.
  # But at present, it doesn't wipe out "useless" value comments,
  # e.g. cleaning this would leave three value markers after the hash.
  Scenario: Multiline output that is repeatedly invoked
    Given the file "mutltiline_output_repeatedly_invoked.rb":
    """
    3.times do
      {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
      # =>
    end
    """
    When I run "seeing_is_believing -x mutltiline_output_repeatedly_invoked.rb"
    Then stdout is:
    """
    3.times do
      {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
      # => {:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
      #    ,{:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
      #    ,{:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
    end
    """
    When I run the pipeline "seeing_is_believing -x mutltiline_output_repeatedly_invoked.rb" | "seeing_is_believing -x"
    Then stdout is:
    """
    3.times do
      {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
      # => {:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
      #    ,{:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
      #    ,{:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
    end
    """


  Scenario: Multiline values where the first line is indented more than the successive lines use a nonbreaking space
    Given the file "inspect_tree.rb":
    """
    bst = Object.new
    def bst.inspect
      "   4\n"\
      " 2   6\n"\
      "1 3 5 7\n"
    end
    bst
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style inspect_tree.rb"
    # NOTE: The first space after the => is a nonbreaking space
    Then stdout is:
    """
    bst = Object.new
    def bst.inspect
      "   4\n"\
      " 2   6\n"\
      "1 3 5 7\n"
    end
    bst
    # =>    4
    #     2   6
    #    1 3 5 7
    """


  Scenario: Leading whitespace on nextline, but not multiline uses normal spaces
    Given the file "nextline_with_leading_whitespace_but_not_multiline.rb":
    """
    o = Object.new
    def o.inspect; " o" end
    o
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style nextline_with_leading_whitespace_but_not_multiline.rb"
    Then stdout is:
    """
    o = Object.new
    def o.inspect; " o" end
    o
    # =>  o
    """


  Scenario: When there are no results for the previous line it looks further back (#77)
    Given the file "heredocs_and_blank_lines.rb":
    """
    # =>

    <<DOC
    1
    DOC
    # =>

    2

    # =>

    if true
      3
      # =>
    else
      4
      # =>
    end
    """
    When I run "seeing_is_believing --xmpfilter-style heredocs_and_blank_lines.rb"
    Then stdout is:
    """
    # =>

    <<DOC
    1
    DOC
    # => "1\n"

    2

    # => 2

    if true
      3
      # => 3
    else
      4
      # =>
    end
    """



  Scenario: Xmpfilter uses the same comment formatting as normal
    Given the file "xmpfilter_result_lengths.rb":
    """
    $stdout.puts "a"*100
    $stderr.puts "a"*100

                 "a"    # =>
                 "aa"   # =>
                 "aaa"  # =>
                 "aaaa" # =>

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # =>

    raise "a"*100
    """
    When I run "seeing_is_believing -x --result-length 10 xmpfilter_result_lengths.rb"
    Then stderr is empty
    And stdout is:
    """
    $stdout.puts "a"*100
    $stderr.puts "a"*100

                 "a"    # => "a"
                 "aa"   # => "aa"
                 "aaa"  # => "aaa"
                 "aaaa" # => "a...

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # => {:...
    #     :...
    #     :...

    raise "a"*100 # ~> Ru...

    # >> aa...

    # !> aa...

    # ~> Ru...
    # ~> aa...
    # ~>
    # ~> xm...
    """

  Scenario: --interline-align and --no-interline-align determine whether adjacent lines with the same number of results get lined up, it defaults to --align
    Given the file "xmpfilter_interline_alignment.rb":
    """
    3.times do |num|
      num     # =>
        .to_s # =>
    end
    """
    When I run "seeing_is_believing -x xmpfilter_interline_alignment.rb"
    Then stderr is empty
    And  the exit status is 0
    And  stdout is:
    """
    3.times do |num|
      num     # => 0,   1,   2
        .to_s # => "0", "1", "2"
    end
    """
    When I run "seeing_is_believing -x --interline-align xmpfilter_interline_alignment.rb"
    Then stderr is empty
    And  the exit status is 0
    And  stdout is:
    """
    3.times do |num|
      num     # => 0,   1,   2
        .to_s # => "0", "1", "2"
    end
    """
    When I run "seeing_is_believing -x --no-interline-align xmpfilter_interline_alignment.rb"
    Then stderr is empty
    And  the exit status is 0
    And  stdout is:
    """
    3.times do |num|
      num     # => 0, 1, 2
        .to_s # => "0", "1", "2"
    end
    """
