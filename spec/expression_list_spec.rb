require 'seeing_is_believing/expression_list'

describe SeeingIsBelieving::ExpressionList do
  subject :list

  # it 'evaluates the on_complete if it is complete' do
  #   var = nil
  #   list.push('a', on_complete: Proc.new { var = 1 }).should == 1
  #   var.should == 1
  # end

  # it 'evaluates the on_incomplete if it is incomplete' do
  #   var = nil
  #   list.push('a+', on_incomplete: Proc.new { var = 2 }).should == 2
  #   var.should == 2
  # end

  # it 'passes the line and line number to the callbacks' do
  #   described_class.new.push 'a', on_complete: Proc.new { |line, line_number|
  #     line.should == 'a'
  #     line_number.should == 1
  #   }
  #   described_class.new.push 'a+', on_incomplete: Proc.new { |line, line_number|
  #     line.should == 'a+'
  #     line_number.should == 1
  #   }
  # end

  # it 'increments the line number for each expression added' do
  #   i = 0
  #   list.push 'a',  on_complete: Proc.new { |_, num| num.should == 1; i += 1 }
  #   list.push 'b+', on_incomplete: Proc.new { |_, num| num.should == 2; i += 10 }
  #   i.should == 11
  # end

  it '???' do
    noops = {on_complete: -> line, children, completions, line_number {
      p [line, children, completions, line_number]
      line+children.join(' ! ')+completions.join('') }, generate: Proc.new {}}
    list.push('a', noops).should == 'a'
    list.push 'a(', noops
    list.push 'b+', noops
    list.push('c', noops).should == 'b+c'
    list.push 'x\\', noops
    list.push '+', noops
    list.push('y', noops).should == 'x\\+y'
    list.push(')', noops).should == 'a(b+c ! x\\+y)'
  end
end
