require 'seeing_is_believing'

describe SeeingIsBelieving::SyntaxAnalyzer do
  it 'knows if syntax is valid' do
    is_valid = lambda { |code| described_class.valid_ruby? code }
    is_valid['1+2'].should be_true
    is_valid['+'].should be_false
    is_valid["=begin\n1\n=end"].should be_true

    # due to what are possibly bugs in Ripper
    # these don't raise any errors, so have to check them explicitly
    is_valid["'"].should be_false
    is_valid["/"].should be_false
    is_valid["=begin"].should be_false
    is_valid[" =begin"].should be_false
    is_valid[" = begin"].should be_false
    is_valid["=begin\n1"].should be_false
    is_valid["=begin\n1\n=end\n=begin"].should be_false
    is_valid["=begin\n1\n=end\n=end"].should be_false
  end

  it 'knows if the expression is a heredoc' do
    is_here_doc = lambda { |code| described_class.here_doc? code }
    is_here_doc["<<A\nA"].should be_true
    is_here_doc["a=<<A\nabc\nA"].should be_true
    is_here_doc["meth(<<A)\nabc\nA"].should be_true
    is_here_doc["meth(<<A)\nabc\nA"].should be_true
    is_here_doc["meth(<<-A)\n abc\n A"].should be_true
    is_here_doc["meth(<<-\"a b\")\n abc\n a b"].should be_true
    is_here_doc["meth(<<-\"a b\", <<something)\n 1\n a b\n2\nsomething"].should be_true

    is_here_doc["a=<<A\nabc\nA\na"].should be_false
    is_here_doc["def meth\nwhateva(<<A)\nabc\nA\nend"].should be_false
    is_here_doc["a << b\nb"].should be_false
    is_here_doc["a<<b\nb"].should be_false
  end

  it 'knows if the expression is an unfinished heredoc' do
    is_unfinished_heredoc = lambda { |code| described_class.unfinished_here_doc? code }
    is_unfinished_heredoc["<<A"].should be_true
    is_unfinished_heredoc["puts <<A, <<B\na\nA"].should be_true
    is_unfinished_heredoc["<<-A\n"].should be_true

    is_unfinished_heredoc["puts <<A\na\nA"].should be_false
    is_unfinished_heredoc["puts <<-A\na\nA"].should be_false
    is_unfinished_heredoc["puts <<-A\na\n A"].should be_false
    is_unfinished_heredoc["puts <<A, <<B\na\nA\nB"].should be_false
  end

  it 'knows if the last line is a comment' do
    is_comment = lambda { |code| described_class.ends_in_comment? code }

    # true
    is_comment['# whatev'].should be_true
    is_comment['a # whatev'].should be_true
    is_comment["a \n b # whatev"].should be_true
    is_comment["=begin\n1\n=end"].should be_true
    is_comment["# Transfer-Encoding: chunked"].should be_true

    # false
    is_comment['a'].should be_false
    is_comment["a # whatev \n b"].should be_false
    is_comment[""].should be_false
    is_comment["=begin\n=end\n\n =end"].should be_false
    pending "Fix comments to not be shit" do
      is_comment[%'"\n\#{1}"'].should be_false
    end
  end

  it 'knows if it contains an unclosed comment' do
    is_unclosed_comment = lambda { |code| described_class.unclosed_comment? code }
    is_unclosed_comment["=begin"].should be_true
    is_unclosed_comment["=begin\n"].should be_true
    is_unclosed_comment["=begin\n1"].should be_true
    is_unclosed_comment["1\n=begin\n1\n"].should be_true
    is_unclosed_comment["1\n=begin\n1\n =end"].should be_true
    is_unclosed_comment["1\n=begin\n1\n=end"].should be_false
    is_unclosed_comment[" =begin"].should be_false
  end

  it 'knows if the line begins a multiline comment' do
    described_class.begins_multiline_comment?('=begin').should be_true
    described_class.begins_multiline_comment?('=begins').should be_false
  end

  it 'knows if the line ends a multiline comment' do
    described_class.ends_multiline_comment?('=end').should be_true
    described_class.ends_multiline_comment?('=ends').should be_false
  end

  it 'knows when the line is a comment' do
    described_class.line_is_comment?('# abc').should be_true
    described_class.line_is_comment?(' # abc').should be_true
    described_class.line_is_comment?('a # abc').should be_false
    described_class.line_is_comment?('abc').should be_false
  end

  # probably don't really need this many tests, but I'm unfamiliar with how thorough Ripper is
  # and already found areas where it doesn't behave correctly
  it 'knows if the code contains an unclosed string' do
    is_unclosed_string = lambda { |code| described_class.unclosed_string? code }
    [%(a),
     %("a"),
     %("a \n"),
     %("a \n a"),
     %(a \n" a"),
     %(a \n' a'),
     %('a' "b"),
     %('a"b'),
     %("a'b"),
     %("a\\""),
     %(%()),
     %(%<>),
     %(%[]),
     %(%{}),
     %(%Q()),
     %(%q()),
     %("\#{""}"),
     %("\#{''}"),
     %("\#{%(\#{%[\#{%[]}]})}"),
     %(%{}),
     %(%<>),
     %(%..),
    ].each do |string|
      is_unclosed_string[string].should be_false, "Expected #{string.inspect} to be closed"
    end

    [%(a "),
     %(a '),
     %("a \n),
     %(a \n 'a\n),
     %("a"\n"b),
     %("a" "b),
     %("a" "b'),
     %("a\\"),
     %('a\\'),
     %(%\(),
     %(%<),
     %(%[),
     %(%{),
     %(%Q[),
     %(%q[),
     %(%Q(\#{)),
     %("\#{),
     %("\#{'}"),
     %("\#{"}"),
     %("\#{%(\#{%[\#{%[}]})}"),
    ].each do |string|
      is_unclosed_string[string].should be_true, "Expected #{string.inspect} to be unclosed"
    end
  end

  it 'knows if the code contains an unclosed regexp' do
    is_unclosed_regexp = lambda { |code| described_class.unclosed_regexp? code }
    [%(a),
     %(/a/),
     %(/a \n/),
     %(/a \n a/),
     %(a \n/ a/),
     %(/a\\//),
     %(/\#{//}/),
     %(%r()),
     %(%r{}),
     %(%r<>),
     %(%r..),
     %(/\na\nb\n/x),
     %(r..i),
     %(/\na\nb\n/xmi),
    ].each do |code|
      is_unclosed_regexp[code].should be_false, "Expected #{code.inspect} to be closed"
    end

    [%(a + /),
     %(/a \n),
     %(a \n /a\n),
     %(/a/\n/b),
     %(/a\\/),
     %(%r\(),
     %(%r<),
     %(%r[),
     %(%r{),
     %(%r(\#{)),
     %(%r[\#{),
     %("\#{%r[}"),
    ].each do |code|
      is_unclosed_regexp[code].should be_true, "Expected #{code.inspect} to be unclosed"
    end
  end

  shared_examples_for 'single line void_value_expression?' do |keyword, options={}|
    specify "`#{keyword}` returns true when the expression ends in #{keyword} without an argument" do
      described_class.void_value_expression?("#{keyword}").should be_true
      described_class.void_value_expression?("#{keyword} if true").should be_true
      described_class.void_value_expression?("o.#{keyword}").should be_false
      described_class.void_value_expression?(":#{keyword}").should be_false
      described_class.void_value_expression?(":'#{keyword}'").should be_false
      described_class.void_value_expression?("'#{keyword}'").should be_false
      described_class.void_value_expression?("def a\n#{keyword}\nend").should be_false
      described_class.void_value_expression?("-> {\n#{keyword}\n}").should be_false
      described_class.void_value_expression?("Proc.new {\n#{keyword}\n}").should be_false
      described_class.void_value_expression?("#{keyword}_something").should be_false
      described_class.void_value_expression?("'#{keyword}\n#{keyword}\n#{keyword}'").should be_false

      unless options[:no_args]
        described_class.void_value_expression?("#{keyword}(1)").should be_true
        described_class.void_value_expression?("#{keyword} 1").should be_true
        described_class.void_value_expression?("#{keyword} 1\n").should be_true
        described_class.void_value_expression?("#{keyword} 1 if true").should be_true
        described_class.void_value_expression?("#{keyword} 1 if false").should be_true
        described_class.void_value_expression?("def a\n#{keyword} 1\nend").should be_false
        described_class.void_value_expression?("-> {\n#{keyword} 1\n}").should be_false
        described_class.void_value_expression?("Proc.new {\n#{keyword} 1\n}").should be_false
        described_class.void_value_expression?("#{keyword} \\\n1").should be_true
      end
    end

    it "knows when an if statement ends in `#{keyword}`" do
      # if
      described_class.void_value_expression?("if true\n#{keyword}\nend").should be_true
      described_class.void_value_expression?("if true\n  #{keyword}\nend").should be_true
      described_class.void_value_expression?("if true\n 1+1\n  #{keyword}\nend").should be_true
      described_class.void_value_expression?("if true\n #{keyword}\n 1+1\n end").should be_false
      described_class.void_value_expression?("123 && if true\n  #{keyword}\nend").should be_false
      described_class.void_value_expression?("def m\n if true\n  #{keyword}\nend\n end").should be_false
      described_class.void_value_expression?("if true; #{keyword}; end").should be_true
      described_class.void_value_expression?("if true; 1; end").should be_false

      # if .. elsif
      described_class.void_value_expression?("if true\n #{keyword}\n elsif true\n 1\n end").should be_true
      described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n end").should be_true
      described_class.void_value_expression?("if true\n #{keyword}\n 2\n elsif true\n 1\n end").should be_false
      described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n 2\n end").should be_false

      # if .. else
      described_class.void_value_expression?("if true\n #{keyword}\n else 1\n end").should be_true
      described_class.void_value_expression?("if true\n 1\n else\n #{keyword}\n end").should be_true
      described_class.void_value_expression?("if true\n #{keyword}\n 2\n else 1\n end").should be_false
      described_class.void_value_expression?("if true\n 1\n else\n #{keyword}\n 2\n end").should be_false

      # if .. elsif .. else .. end
      described_class.void_value_expression?("if true\n #{keyword}\nelsif true\n 1 else 1\n end").should be_true
      described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n else\n 1\n end").should be_true
      described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n elsif true\n #{keyword}\n else\n 1\n end").should be_true
      described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n else\n #{keyword}\n end").should be_true
      described_class.void_value_expression?("if true\n #{keyword}\n 2\nelsif true\n 1 else 1\n end").should be_false
      described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n 2\n else\n 1\n end").should be_false
      described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n elsif true\n #{keyword}\n 2\n else\n 1\n end").should be_false
      described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n else\n #{keyword}\n 2\n end").should be_false

      unless options[:no_args]
        # if
        described_class.void_value_expression?("if true\n#{keyword} 1\nend").should be_true
        described_class.void_value_expression?("if true\n  #{keyword} 1\nend").should be_true
        described_class.void_value_expression?("if true\n 1+1\n  #{keyword} 1\nend").should be_true
        described_class.void_value_expression?("if true\n #{keyword} 1\n 1+1\n end").should be_false
        described_class.void_value_expression?("123 && if true\n  #{keyword} 1\nend").should be_false
        described_class.void_value_expression?("def m\n if true\n  #{keyword} 1\nend\n end").should be_false
        described_class.void_value_expression?("if true; #{keyword} 1; end").should be_true
        described_class.void_value_expression?("if true; 1; end").should be_false

        # if .. elsif
        described_class.void_value_expression?("if true\n #{keyword} 1\n elsif true\n 1\n end").should be_true
        described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n end").should be_true
        described_class.void_value_expression?("if true\n #{keyword} 1\n 2\n elsif true\n 1\n end").should be_false
        described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n 2\n end").should be_false

        # if .. else
        described_class.void_value_expression?("if true\n #{keyword} 1\n else 1\n end").should be_true
        described_class.void_value_expression?("if true\n 1\n else\n #{keyword}\n end").should be_true
        described_class.void_value_expression?("if true\n #{keyword} 1\n 2\n else 1\n end").should be_false
        described_class.void_value_expression?("if true\n 1\n else\n #{keyword}\n 2\n end").should be_false

        # if .. elsif .. else .. end
        described_class.void_value_expression?("if true\n #{keyword} 1\nelsif true\n 1 else 1\n end").should be_true
        described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n else\n 1\n end").should be_true
        described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n elsif true\n #{keyword}\n else\n 1\n end").should be_true
        described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n else\n #{keyword}\n end").should be_true
        described_class.void_value_expression?("if true\n #{keyword} 1\n 2\nelsif true\n 1 else 1\n end").should be_false
        described_class.void_value_expression?("if true\n 1\n elsif true\n #{keyword}\n 2\n else\n 1\n end").should be_false
        described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n elsif true\n #{keyword}\n 2\n else\n 1\n end").should be_false
        described_class.void_value_expression?("if true\n 1\n elsif true\n 1\n else\n #{keyword}\n 2\n end").should be_false
      end
    end

    it "knows when a begin statement ends in `#{keyword}`" do
      described_class.void_value_expression?("begin\n #{keyword}\n end").should be_true
      described_class.void_value_expression?("begin\n 1\n #{keyword}\n end").should be_true
      described_class.void_value_expression?("begin\n #{keyword}\n 1\n end").should be_false
      described_class.void_value_expression?("begin\n 1\n #{keyword}\n 1\n end").should be_false

      unless options[:no_args]
        described_class.void_value_expression?("begin\n #{keyword} '123' \n end").should be_true
        described_class.void_value_expression?("begin\n 1\n #{keyword} 456\n end").should be_true
        described_class.void_value_expression?("begin\n #{keyword} :'789'\n 1\n end").should be_false
        described_class.void_value_expression?("begin\n 1\n #{keyword} /101112/\n 1\n end").should be_false
      end

      # I don't know that the rest of these hold across all versions of Ruby since they make no fucking sense
      # so even though some of them can technically be non-vve,
      # I'm still going to call any one of them a vve
      #
      # e.g. (tested on 2.0)
      #   this is allowed
      #     -> { a = begin;  return
      #              rescue; return
      #              ensure; return
      #              end }
      #   this is not
      #     -> { a = begin; return
      #              end }

      # with rescue...
      described_class.void_value_expression?("begin\n #{keyword}\n rescue\n #{keyword} end").should be_true
      described_class.void_value_expression?("begin\n 1\n #{keyword}\n rescue RuntimeError => e\n end").should be_true
      described_class.void_value_expression?("begin\n 1\n #{keyword}\n rescue RuntimeError\n end").should be_true
      described_class.void_value_expression?("begin\n 1\n #{keyword}\n rescue\n end").should be_true
      described_class.void_value_expression?("begin\n 1\n rescue\n end").should be_false
      described_class.void_value_expression?("begin\n 1\n rescue\n #{keyword}\n end").should be_true
      described_class.void_value_expression?("begin\n 1\n rescue\n #{keyword}\n 1\n end").should be_false

      unless options[:no_args]
        described_class.void_value_expression?("begin\n #{keyword}\n rescue\n #{keyword} 1 end").should be_true
        described_class.void_value_expression?("begin\n 1\n #{keyword} 1\n rescue RuntimeError => e\n end").should be_true
        described_class.void_value_expression?("begin\n 1\n #{keyword} 1\n rescue RuntimeError\n end").should be_true
        described_class.void_value_expression?("begin\n 1\n #{keyword} :abc\n rescue\n end").should be_true
        described_class.void_value_expression?("begin\n 1\n rescue\n #{keyword} 'abc'\n end").should be_true
        described_class.void_value_expression?("begin\n 1\n rescue\n #{keyword} :abc\n 1\n end").should be_false
      end

      # with ensure
      described_class.void_value_expression?("begin\n #{keyword}\n ensure\n #{keyword} end").should be_true
      described_class.void_value_expression?("begin\n 1\n #{keyword}\n ensure\n end").should be_true
      described_class.void_value_expression?("begin\n 1\n ensure\n end").should be_false
      described_class.void_value_expression?("begin\n 1\n ensure\n #{keyword}\n end").should be_true
      described_class.void_value_expression?("begin\n 1\n ensure\n #{keyword}\n 1\n end").should be_false

      unless options[:no_args]
        described_class.void_value_expression?("begin\n #{keyword}\n ensure\n #{keyword} 1 end").should be_true
        described_class.void_value_expression?("begin\n 1\n #{keyword} 1\n ensure\n end").should be_true
        described_class.void_value_expression?("begin\n 1\n #{keyword} :abc\n ensure\n end").should be_true
        described_class.void_value_expression?("begin\n 1\n ensure\n #{keyword} 'abc'\n end").should be_true
        described_class.void_value_expression?("begin\n 1\n ensure\n #{keyword} :abc\n 1\n end").should be_false
      end

      # with ensure and rescue
      described_class.void_value_expression?("begin\n 1\n          rescue\n 2\n          ensure\n 3\n          end").should be_false
      described_class.void_value_expression?("begin\n #{keyword}\n rescue\n 2\n          ensure\n 3\n          end").should be_true
      described_class.void_value_expression?("begin\n 1\n          rescue\n #{keyword}\n ensure\n 3\n          end").should be_true
      described_class.void_value_expression?("begin\n 1\n          rescue\n 2\n          ensure\n #{keyword}\n end").should be_true
    end
  end

  it_should_behave_like 'single line void_value_expression?', 'return'
  it_should_behave_like 'single line void_value_expression?', 'next'
  it_should_behave_like 'single line void_value_expression?', 'break'

  it_should_behave_like 'single line void_value_expression?', 'redo',  no_args: true
  it_should_behave_like 'single line void_value_expression?', 'retry', no_args: true

  it 'knows when a line opens the data segment' do
    described_class.begins_data_segment?('__END__').should be_true
    described_class.begins_data_segment?('__ENDS__').should be_false
  end

  it 'knows when the next line modifies the current line' do
    described_class.next_line_modifies_current?('.meth').should be_true
    described_class.next_line_modifies_current?(' .meth').should be_true

    described_class.next_line_modifies_current?('meth').should be_false
    described_class.next_line_modifies_current?(' meth').should be_false
  end
end
