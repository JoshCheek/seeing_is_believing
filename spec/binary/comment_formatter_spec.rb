require 'seeing_is_believing/binary/comment_formatter'

describe SeeingIsBelieving::Binary::CommentFormatter do
  def result_for(line, separator, result, options={})
    described_class.new(line, separator, result, options).call
  end

  specify 'it returns the consolidated result if there are no truncations' do
    result_for(1, '=>', '12345').should == '=>12345'
  end

  specify 'result_length truncates a result to the specified length, using elipses up to that length if appropriate'  do
    line_length = 1
    separator   = '=>'
    result      = '12345'
    result_for(line_length, separator, result, max_result_length: Float::INFINITY).should == '=>12345'
    result_for(line_length, separator, result, max_result_length: 7).should == '=>12345'
    result_for(line_length, separator, result, max_result_length: 6).should == '=>1...'
    result_for(line_length, separator, result, max_result_length: 5).should == '=>...'
    result_for(line_length, separator, result, max_result_length: 4).should == ''
    result_for(line_length, separator, result, max_result_length: 0).should == ''
  end

  specify 'line_length truncates a result to the specified length, minus the length of the line' do
    line_length = 1
    separator   = '=>'
    result      = '12345'
    result_for(line_length, separator, result).should == '=>12345'
    result_for(line_length, separator, result, max_line_length: Float::INFINITY).should == '=>12345'
    result_for(line_length, separator, result, max_line_length: 8).should == '=>12345'
    result_for(line_length, separator, result, max_line_length: 7).should == '=>1...'
    result_for(line_length, separator, result, max_line_length: 6).should == '=>...'
    result_for(line_length, separator, result, max_line_length: 5).should == ''
    result_for(line_length, separator, result, max_line_length: 0).should == ''
  end

  specify 'pad_to will pad the length that the line is displayed in' do
    result_for(1, '=>', '2', pad_to: 0).should == '=>2'
    result_for(1, '=>', '2', pad_to: 1).should == '=>2'
    result_for(1, '=>', '2', pad_to: 2).should == ' =>2'
  end

  specify 'pad_to is ignored when separator/result will not be printed' do
    result_for(1, '=>', '12345', pad_to: 2,   max_line_length: 2).should == ''
    result_for(1, '=>', '12345', pad_to: 2, max_result_length: 2).should == ''
  end

  specify 'they can all work together' do
    result_for(1, '=>', '12345', max_line_length: 100, max_result_length: 100, pad_to: 2).should == ' =>12345'
    result_for(1, '=>', '12345', max_line_length:   8, max_result_length: 100, pad_to: 2).should == ' =>1...'
    result_for(1, '=>', '12345', max_line_length: 100, max_result_length:   6, pad_to: 2).should == ' =>1...'
    result_for(1, '=>', '12345', max_line_length: 100, max_result_length:   6, pad_to: 2).should == ' =>1...'
  end
end
