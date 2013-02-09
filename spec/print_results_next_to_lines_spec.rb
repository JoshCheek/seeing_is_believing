require 'seeing_is_believing/print_results_next_to_lines'
require 'stringio'

describe SeeingIsBelieving::PrintResultsNextToLines do
  def new(options={})
    body  = options.fetch :body, ''
    stdin = options.fetch :stdin, StringIO.new
    described_class.new(body, stdin, options)
  end

  describe '#truncate_result' do
    it 'returns the string if there is no line length set' do
      instance, string = new, "abc"
      string.size.should be < instance.result_length
      instance.truncate_result(string).should == string
    end

    it 'returns the string if it is less than or equal to the line_length' do
      new(result_length: 5).truncate_result('1234').should == '1234'
      new(result_length: 5).truncate_result('12345').should == '12345'
    end

    it 'returns as much of the string as it can (minus three chars used for an elipsis)' do
      new(result_length: 4).truncate_result('12345').should == '1...'
      new(result_length: 3).truncate_result('12345').should == '...'
      new(result_length: 2).truncate_result('12345').should == '..'
      new(result_length: 1).truncate_result('12345').should == '.'
    end
  end
end
