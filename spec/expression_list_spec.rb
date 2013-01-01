require 'seeing_is_believing/expression_list'

describe SeeingIsBelieving::ExpressionList do

  def call(generations, options={}, &block)
    options = { generator: -> { generations.shift || raise("EMPTY!") }, on_complete: block }.merge(options)
    described_class.new(options).call
  end

  example 'shows: multiple children' do
    block_invocations = 0
    result = call %w[a( b+ c x\\ + y )] do |line, children, completions, line_number|
      case line_number
      when 3
        line.should == 'b+'
        children.should == []
        completions.should == ['c']
        block_invocations += 1
        'b+c'
      when 6
        line.should == 'x\\'
        children.should == []
        completions.should == ['+', 'y']
        block_invocations += 10
        'x\\+y'
      when 7
        line.should == 'a('
        children.should == ['b+c', 'x\\+y']
        completions.should == [')']
        block_invocations += 100
        'ALL DONE!'
      else
        require "pry"
        binding.pry
      end
    end
    result.should == 'ALL DONE!'
    block_invocations.should == 111
  end


  example 'shows: nested children' do
    expressions = [ '[1].map do |n1|',
                    '  [2].map do |n2|',
                    '    n1 + n2',
                    '  end',
                    'end',
                  ]
    result = call expressions do |line, children, completions, line_number|
      case line_number
      when 3
        [line, children, completions].should == ['    n1 + n2', [], []]
        line
      when 4
        [line, children, completions].should == ['  [2].map do |n2|', ['    n1 + n2'], ['  end']]
        [line, *children, *completions].join("\n")
      when 5
        [line, children, completions].should == ['[1].map do |n1|',
                                                 ["  [2].map do |n2|\n    n1 + n2\n  end"],
                                                 ['end']]
        [line, *children, *completions].join("\n")
      end
    end
    result.should ==  "[1].map do |n1|\n"\
                      "  [2].map do |n2|\n"\
                      "    n1 + n2\n"\
                      "  end\n"\
                      "end"
  end
end
