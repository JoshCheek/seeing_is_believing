require 'seeing_is_believing'

describe SeeingIsBelieving::SyntaxAnalyzer do
  it 'knows if syntax is valid' do
    is_valid = lambda { |code| described_class.valid_ruby? code }
    is_valid['+'].should be_false
    is_valid['1+2'].should be_true
  end

  it 'knows if the last line is a comment' do
    is_comment = lambda { |code| described_class.ends_in_comment? code }
    is_comment['# whatev'].should be_true
    is_comment['a # whatev'].should be_true
    is_comment["a \n b # whatev"].should be_true
    is_comment['a'].should be_false
    is_comment["a # whatev \n b"].should be_false
  end
end
