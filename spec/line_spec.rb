require 'spec_helper'
require 'seeing_is_believing/result'

describe SeeingIsBelieving::Line do
  Line = described_class

  def line_for(*args)
    line = Line.new
    args.each { |a| line.record_result a }
    line
  end

  it 'inspects prettily' do
    expect(line_for(       ).inspect).to eq '#<SIB:Line[] (0, 0) no exception>'
    expect(line_for("a"    ).inspect).to eq '#<SIB:Line["\"a\""] (1, 3) no exception>'
    expect(line_for("a", 12).inspect).to eq '#<SIB:Line["\"a\"", "12"] (2, 5) no exception>'

    line = Line.new
    line.exception = RuntimeError.new("omg")
    expect(line.inspect).to eq '#<SIB:Line[] (0, 0) RuntimeError:"omg">'
  end

  it "doesn't blow up when there is no #inspect available e.g. BasicObject" do
    obj = BasicObject.new
    expect(line_for(obj).inspect).to eq '#<SIB:Line["#<no inspect available>"] (1, 23) no exception>'
  end

  it "doesn't blow up when #inspect returns a not-String (e.g. pathalogical libraries like FactoryGirl)" do
    obj = BasicObject.new
    def obj.inspect
      nil
    end
    expect(line_for(obj).inspect).to eq '#<SIB:Line["#<no inspect available>"] (1, 23) no exception>'
  end

  it 'knows when it has an exception' do
    exception = RuntimeError.new 'omg'
    line = Line.new
    expect(line).to_not have_exception
    line.exception = exception
    expect(line).to have_exception
    expect(line.exception).to equal exception
  end

  it 'delegates its other methods to array, but returns itself where the array would be returned' do
    line = Line.new
    expect(line).to be_empty
    expect((line << 1)).to equal line
    expect(line).to_not be_empty
    expect(line.map { |i| i * 2 }).to eq [2]
    line << 10 << 100
    expect(line.take(2)).to eq [1, 10]
  end

  it 'returns its array for #to_a and #to_ary' do
    line = line_for 1, 2
    expect(line.to_a).to be_a_kind_of Array
    expect(line.to_a).to eq %w[1 2]
    expect(line.to_ary).to be_a_kind_of Array
    expect(line.to_ary).to eq %w[1 2]
  end

  it 'is equal to arrays with the same elements as its array' do
    expect(line_for(1, 2)).to eq %w[1 2]
    expect(line_for(1, 2)).to_not eq %w[2 1]
  end

  # Exception equality seems to be based off of the message, and be indifferent to the class, I don't think it's that important to fix it
  it "is equal to lines with the same elements and the same exception" do
    exception = RuntimeError.new 'omg'

    expect(line_for(1, 2)).to eq line_for(1, 2)
    expect(line_for(1, 2)).to_not eq line_for(2, 1)

    line1 = line_for(1, 2)
    line1.exception = exception
    expect(line1).to_not eq line_for(1, 2)

    line2 = line_for(1, 2)
    line2.exception = exception
    expect(line1).to eq line2

    line2.exception = RuntimeError.new 'wrong message'
    expect(line1).to_not eq line2
  end
end
