require 'seeing_is_believing/expression_list'

describe SeeingIsBelieving::ExpressionList do
  subject :list

  it 'evaluates and returns the on_complete if it is complete' do
    var = nil
    list.push('a', on_complete: Proc.new { var = 1 }).should == 1
    var.should == 1
  end

  it 'evaluates generate if it is incomplete' do
    var = nil
    list.push('a+', generate: lambda { var = 2 }).should == 2
    var.should == 2
  end

  it 'passes the line, children, expressions that complete the current expression, and line number to the on_complete callback' do
    described_class.new.push 'a', on_complete: lambda { |line, children, completions, line_number|
      line.should == 'a'
      line_number.should == 1
    }
  end

  it 'increments the line number for each expression added' do
    i = 0
    list.push 'a',  on_complete: lambda { |_, _, _, num| num.should == 1; i += 1   }
    list.push 'b+', on_complete: lambda { |_, _, _, num| num.should == 3; i += 10  }, generate: lambda {}
    list.push 'a',  on_complete: lambda { |_, _, _, num| num.should == 3; i += 100 }
    i.should == 11
  end

  example 'example1' do
    callbacks = { generate: Proc.new {},
                  on_complete: -> line, children, completions, line_number do
                    line+children.join(' ! ')+completions.join('')
                  end
                }
    list.push('a',   callbacks).should == 'a'
    list.push('a(',  callbacks)
    list.push('b+',  callbacks)
    list.push('c',   callbacks).should == 'b+c'
    list.push('x\\', callbacks)
    list.push('+',   callbacks)
    list.push('y',   callbacks).should == 'x\\+y'
    list.push(')',   callbacks).should == 'a(b+c ! x\\+y)'
  end

  example 'example2' do
    list = described_class.new
    callbacks = { generate: Proc.new {},
                  on_complete: -> line, children, completions, line_number do
                    line+children.join("\n")+completions.join("\n")
                  end
                }
    list.push('[1].map do |n1|', callbacks.merge(
      generate: -> {
        list.push('  [2].map do |n2|', callbacks.merge(
          generate: -> {
            list.push('    n1 + n2', callbacks.merge(
              generate: -> {
                list.push('  end', callbacks.merge(
                  generate: -> { list.push 'end', callbacks }
                ))
              }
            ))
          }
        ))
      }
    )).should ==  "[1].map do |n1|"\
                  "  [2].map do |n2|"\
                  "    n1 + n2"\
                  "  end"\
                  "end"
  end
end
