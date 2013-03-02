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

  it 'knows if the last line is a comment' do
    is_comment = lambda { |code| described_class.ends_in_comment? code }

    # true
    is_comment['# whatev'].should be_true
    is_comment['a # whatev'].should be_true
    is_comment["a \n b # whatev"].should be_true
    is_comment["=begin\n1\n=end"].should be_true

    # false
    is_comment['a'].should be_false
    is_comment["a # whatev \n b"].should be_false
    is_comment[""].should be_false
    is_comment["=begin\n=end\n\n =end"].should be_false
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

  # the commented out ones will require actual parsing to solve
  it "knows if the code contains a return (can't capture a void value)" do
    will_return = -> code { described_class.will_return? code }
    will_return["return 1"].should be_true
    will_return["return 1\n"].should be_true
    will_return["return 1 if true"].should be_true
    will_return["return 1 if false"].should be_true
    will_return["o.return"].should be_false
    will_return[":return"].should be_false
    will_return["'return'"].should be_false
    will_return["def a\nreturn 1\nend"].should be_false
    will_return["-> {\nreturn 1\n}"].should be_false
    will_return["Proc.new {\nreturn 1\n}"].should be_false
    pending "this doesn't work because the return detecting code is an insufficient regexp" do
      will_return["'return\nreturn\nreturn'"].should be_false
      will_return["return \\\n1"].should be_true
    end
  end
end
