require 'seeing_is_believing/line_formatter'

describe SeeingIsBelieving::LineFormatter do
  def result_for(line, separator, result, options={})
    described_class.new(line, separator, result, options).call
  end

  specify 'it returns the consolidated result if there are no truncations' do
    result_for('1', '=>', '12345').should == '1=>12345'
  end

  specify 'result_length truncates a result to the specified length, using elipses up to that length if appropriate'  do
    line      = '1'
    separator = '=>'
    result    = '12345'
    result_for(line, separator, result, result_length: Float::INFINITY).should == '1=>12345'
    result_for(line, separator, result, result_length: 7).should == '1=>12345'
    result_for(line, separator, result, result_length: 6).should == '1=>1...'
    result_for(line, separator, result, result_length: 5).should == '1=>...'
    result_for(line, separator, result, result_length: 4).should == '1'
    result_for(line, separator, result, result_length: 0).should == '1'
  end

  specify 'line_length truncates a result to the specified length, minus the length of the line' do
    line      = '1'
    separator = '=>'
    result    = '12345'
    result_for(line, separator, result).should == '1=>12345'
    result_for(line, separator, result, line_length: Float::INFINITY).should == '1=>12345'
    result_for(line, separator, result, line_length: 8).should == '1=>12345'
    result_for(line, separator, result, line_length: 7).should == '1=>1...'
    result_for(line, separator, result, line_length: 6).should == '1=>...'
    result_for(line, separator, result, line_length: 5).should == '1'
    result_for(line, separator, result, line_length: 0).should == '1'
  end

  specify 'result_length and line_length can work together' do
    line      = '1'
    separator = '=>'
    result    = '12345'
    result_for(line, separator, result, line_length: 100, result_length: 100).should == '1=>12345'
    result_for(line, separator, result, line_length:   7, result_length: 100).should == '1=>1...'
    result_for(line, separator, result, line_length: 100, result_length:   6).should == '1=>1...'
  end
end
