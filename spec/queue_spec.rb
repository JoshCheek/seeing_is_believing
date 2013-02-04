require 'seeing_is_believing/queue'

describe SeeingIsBelieving::Queue do
  def queue_for(*values)
    described_class.new { values.shift }
  end

  it 'generates values from the block it is initialized with' do
    queue = queue_for 1, 2
    queue.dequeue.should == 1
    queue.dequeue.should == 2
    queue.dequeue.should == nil
  end

  it 'can peek ahead' do
    queue = queue_for 1, 2
    queue.peek.should == 1
    queue.peek.should == 1
    queue.dequeue.should == 1
    queue.dequeue.should == 2
  end

  it 'considers a nil value to mean it is empty' do
    queue = queue_for 1, 2
    queue.should_not be_empty
    queue.peek.should == 1
    queue.should_not be_empty
    queue.dequeue.should == 1
    queue.should_not be_empty
    queue.peek.should == 2
    queue.should_not be_empty
    queue.dequeue.should == 2
    queue.should be_empty
    queue.peek.should == nil
  end

  it 'yields nil infinitely after the first time it is seen' do
    queue = queue_for nil, 1
    queue.should be_empty
    queue.peek.should == nil
    queue.dequeue.should == nil
    queue.should be_empty
    queue.peek.should == nil
    queue.dequeue.should == nil
  end

  describe 'conditional iteration' do
    it 'will iterate while a condition is met' do
      queue = queue_for *1..5
      seen = []
      queue.while { |arg| arg < 4 }.each { |arg| seen << arg }
      seen.should == [1, 2, 3]
      queue.peek.should == 4
    end

    it 'will iterate until a condition is met' do
      queue = queue_for *1..5
      seen = []
      queue.until { |arg| arg == 4 }.each { |arg| seen << arg }
      seen.should == [1, 2, 3]
      queue.peek.should == 4
    end

    it 'stops iterating when it hits the end of the queue' do
      queue = queue_for *1..5
      seen = []
      queue.while { true }.each { |arg| seen << arg }
      seen.should == [*1..5]
      queue.should be_empty
    end
  end
end
