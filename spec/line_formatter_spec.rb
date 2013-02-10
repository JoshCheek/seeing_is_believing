require 'seeing_is_believing/binary/line_formatter'

describe SeeingIsBelieving::Binary::LineFormatter do
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

  specify 'source_length will alter the length that the line is displayed in' do
    result_for('1', '=>', '2', source_length: 0).should == '1=>2'
    result_for('1', '=>', '2', source_length: 1).should == '1=>2'
    result_for('1', '=>', '2', source_length: 2).should == '1 =>2'
  end

  specify 'source_length is ignored when separator/result will not be printed' do
    result_for('1', '=>', '12345', source_length: 2,   line_length: 2).should == '1'
    result_for('1', '=>', '12345', source_length: 2, result_length: 2).should == '1'
  end

  specify 'they can all work together' do
    result_for('1', '=>', '12345', line_length: 100, result_length: 100, source_length: 2).should == '1 =>12345'
    result_for('1', '=>', '12345', line_length:   8, result_length: 100, source_length: 2).should == '1 =>1...'
    result_for('1', '=>', '12345', line_length: 100, result_length:   6, source_length: 2).should == '1 =>1...'
  end
end
