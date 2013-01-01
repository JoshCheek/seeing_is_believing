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

  it 'records the value immediately, so that it is correct even if it changes' do
    values_for("a = 'a'\na << 'b'").should == [['"a"'], ['"ab"']]
  end

  it 'records each value when a line is evaluated multiple times' do
    values_for("(1..2).each do |i|\ni\nend").should == [[], ['1', '2'], ['1..2']]
  end

  it 'evalutes to an empty array for lines that it cannot understand' do
    values_for("[3].map do |n|\n n*2\n end").should == [[], ['6'], ['[6]']]
    values_for("[1].map do |n1|
                  [2].map do |n2|
                    n1 + n2
                  end
                end").should == [[], [], ['3'], ['[3]'], ['[[3]]']]

    values_for("[1].map do |n1|
                  [2].map do |n2| n1 + n2
                  end
                end").should == [[], [], ['[3]'], ['[[3]]']]

    values_for("[1].map do |n1|
                  [2].map do |n2|
                    n1 + n2 end
                end").should == [[], [], ['[3]'], ['[[3]]']]

    values_for("[1].map do |n1|
                  [2].map do |n2|
                    n1 + n2 end end").should == [[], [], ['[[3]]']]

    values_for("[1].map do |n1|
                  [2].map do |n2| n1 + n2 end end").should == [[], ['[[3]]']]

    values_for("[1].map do |n1| [2].map do |n2| n1 + n2 end end").should == [['[[3]]']]

    values_for("[1].map do |n1|
                  [2].map do |n2|
                    n1 + n2
                end end").should == [[], [], ['3'], ['[[3]]']]

    values_for("[1].map do |n1| [2].map do |n2|
                  n1 + n2
                end end").should == [[], ['3'], ['[[3]]']]

    values_for("[1].map do |n1| [2].map do |n2|
                  n1 + n2 end end").should == [[], ['[[3]]']]

    values_for("[1].map do |n1| [2].map do |n2|
                  n1 + n2 end
                end").should == [[], [], ['[[3]]']]

    values_for("1 +
                    2").should == [[], ['3']]
  end

  # something about empty lines
  # something about multi-line strings
  # something about raised errors
  # something about printing to stdout
  # something about printing to stderr
  # something about when the whole input is invalid
end
