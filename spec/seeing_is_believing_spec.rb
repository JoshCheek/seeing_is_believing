require 'seeing_is_believing'
require 'stringio'

describe SeeingIsBelieving do
  def invoke(input)
    described_class.new(input).call
  end

  def values_for(input)
    invoke(input).map(&:last)
  end

  def stream(string)
    StringIO.new string
  end

  it 'takes a string or stream and returns a result of the line numbers (counting from 1) and each inspected result from that line' do
    input  = "1+1\n'2'+'2'"
    output = [[1, ["2"]], [2, ['"22"']]]
    invoke(input).should == output
    invoke(stream input).should == output
  end

  it 'remembers context of previous lines' do
    values_for("a=12\na*2").should == [['12'], ['24']]
  end

  it 'can be invoked multiple times, returning the same result' do
    believer = described_class.new("$xyz||=1\n$xyz+=1")
    believer.call.should == [[1, ['1']], [2, ['2']]]
    believer.call.should == [[1, ['1']], [2, ['2']]]
  end

  it 'is evaluated at the toplevel' do
    values_for('self').should == [['main']]
  end

  it 'evalutes to an empty array for lines that it cannot understand' do
    values_for("[3].map do |n|\n n*2\n end").should == [[], ['6'], ['[6]']]
  end

  # something about nested invalid lines: [3].map do |n|\n [3].map do |n2|\n n+n2\n end\n end

  # return arrays of results instead of nil or value

  # something about lines that get evaluated multiple times
  # something about multi-line strings

  # something about errors
  # something about stdout
  # something about stderr
end
