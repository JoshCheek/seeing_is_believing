require 'seeing_is_believing/expression_list'

describe SeeingIsBelieving::ExpressionList do

  def call(generations, options={}, &block)
    options = { on_complete: block, generator: -> { generations.shift || raise("EMPTY!") } }.merge(options)
    described_class.new(options).call
  end

  example 'example: multiple children' do
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
        raise "line_number: #{line_number.inspect}"
      end
    end
    result.should == 'ALL DONE!'
    block_invocations.should == 111
  end


  example 'example: nested children' do
    block_invocations = 0
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
        block_invocations += 1
      when 4
        [line, children, completions].should == ['  [2].map do |n2|', ['    n1 + n2'], ['  end']]
        block_invocations += 10
      when 5
        [line, children, completions].should == ['[1].map do |n1|',
                                                 ["  [2].map do |n2|\n    n1 + n2\n  end"],
                                                 ['end']]
        block_invocations += 100
      else
        raise "line_number: #{line_number.inspect}"
      end
      [line, *children, *completions].join("\n")
    end
    block_invocations.should == 111
    result.should ==  "[1].map do |n1|\n"\
                      "  [2].map do |n2|\n"\
                      "    n1 + n2\n"\
                      "  end\n"\
                      "end"
  end


  example 'example: completions that have children' do
    block_invocations = 0
    expressions = [ "[1].map do |n1|",
                      "[2].map do |n2|",
                        "n1 + n2",
                     "end end",
                  ]
    result = call expressions do |line, children, completions, line_number|
      case line_number
      when 3
        [line, children, completions].should == ["n1 + n2", [], []]
        block_invocations += 1
      when 4
        # not really sure what this *should* be like, but if this is the result,
        # then it will work for the use cases I need it for
        [line, *children, *completions].should == ["[1].map do |n1|",
                                                   "[2].map do |n2|",
                                                   "n1 + n2",
                                                   'end end']
        block_invocations += 10
      else
        raise "line_number: #{line_number.inspect}"
      end
      [line, *children, *completions].join("\n")
    end
    block_invocations.should == 11
    result.should == "[1].map do |n1|\n"\
                      "[2].map do |n2|\n"\
                        "n1 + n2\n"\
                     "end end"\
  end

  example 'example: multiline strings with valid code in them' do
    block_invocations = 0
    call ["'", "1", "'"] do |*expressions, line_number|
      expressions.join('').should == "'1'"
      line_number.should == 3
      block_invocations += 1
    end
    block_invocations.should == 1
  end

  example 'example: multiline regexps with valid code in them' do
    block_invocations = 0
    call ['/', '1', '/'] do |*expressions, line_number|
      expressions.join('').should == "/1/"
      line_number.should == 3
      block_invocations += 1
    end
    block_invocations.should == 1
  end

  example "example: =begin/=end comments" do
    block_invocations = 0
    call ['=begin', '1', '=end'] do |*expressions, line_number|
      expressions.join('').should == "=begin1=end"
      line_number.should == 3
      block_invocations += 1
    end
    block_invocations.should == 1
  end

  example "example: heredoc" do
    pending 'Not sure how to do this, for now just catch it at a higher level' do
      result = call ['strings = [<<A, <<-B]', '1', 'A', '2', ' B'] do |*expressions, line_number|
        line_number.should == 1
        expressions.should == ['strings = [<<A, <<B]']
        'zomg!'
      end
      result.should == "zomg!\n1\nA\n2\n B"
    end
  end

  example "example: smoke test debug option" do
    stream = StringIO.new
    call(%w[a+ b], debug: true, debug_stream: stream) { |*expressions, _| expressions.join("\n") }
    stream.string.should include "GENERATED"
    stream.string.should include "REDUCED"
  end

  # in reality, the problem may just lie with our lib
  # but it should be correct in most cases
  it 'Raises a syntax error if it cannot generate the expression' do
    generations = ["'"]
    expect do
      described_class.new(
        on_complete: -> { "" }, generator: -> { generations.shift }
      ).call
    end.to raise_error SyntaxError
  end
end
