require 'seeing_is_believing'

describe SeeingIsBelieving::SyntaxAnalyzer do
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

  it 'knows when a line opens the data segment' do
    described_class.begins_data_segment?('__END__').should be_true
    described_class.begins_data_segment?('__ENDS__').should be_false
  end
end
