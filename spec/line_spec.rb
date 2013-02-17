require 'seeing_is_believing/result'

describe SeeingIsBelieving::Line do
  Line = described_class

  it 'inspects prettily' do
    Line[].inspect.should == '#<SIB:Line[] no exception>'
    Line["a"].inspect.should == '#<SIB:Line["a"] no exception>'
    Line["a", 1].inspect.should == '#<SIB:Line["a", 1] no exception>'
    line = Line[]
    line.exception = RuntimeError.new("omg")
    line.inspect.should == '#<SIB:Line[] RuntimeError:"omg">'
  end

  it 'knows when it has an exception' do
    exception = RuntimeError.new 'omg'
    line = Line.new
    line.should_not have_exception
    line.exception = exception
    line.should have_exception
    line.exception.should equal exception
  end

  it 'delegates its other methods to array, but returns itself where the array would be returned' do
    line = Line.new
    line.should be_empty
    (line << 1).should equal line
    line.should_not be_empty
    line.map { |i| i * 2 }.should == [2]
    line << 10 << 100
    line.take(2).should == [1, 10]
  end

  it 'returns its array for #to_a and #to_ary' do
    line = Line[1,2]
    line.to_a.should be_a_kind_of Array
    line.to_a.should == [1, 2]
    line.to_ary.should be_a_kind_of Array
    line.to_ary.should == [1, 2]
  end

  it 'is equal to arrays with the same elements as its array' do
    Line[1, 2].should == [1, 2]
    Line[1, 2].should_not == [2, 1]
  end

  # Exception equality seems to be based off of the message, and be indifferent to the class, I don't think it's that important to fix it
  it "is equal to lines with the same elements and the same exception" do
    exception = RuntimeError.new 'omg'

    Line[1, 2].should == Line[1, 2]
    Line[1, 2].should_not == Line[2, 1]

    line1 = Line[1, 2]
    line1.exception = exception
    line1.should_not == Line[1, 2]

    line2 = Line[1, 2]
    line2.exception = exception
    line1.should == line2

    line2.exception = RuntimeError.new 'wrong message'
    line1.should_not == line2
  end
end
