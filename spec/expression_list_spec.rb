require 'seeing_is_believing/expression_list'

describe SeeingIsBelieving::ExpressionList do

  def list_for(generations, options={}, &block)
    described_class.new({
      on_complete:    block,
      get_next_line:  -> { generations.shift || raise("EMPTY!") },
      peek_next_line: -> { generations.first },
    }.merge(options))
  end

  def call(generations, options={}, &block)
    list_for(generations, options, &block).call
  end

  example 'example: multiple children' do
    block_invocations = 0
    result, size = call %w[begin b+ c x\\ + y end] do |line, children, completions, offset|
      case offset
      when 2
        line.should == 'b+'
        children.should == []
        completions.should == ['c']
        block_invocations += 1
        'b+c'
      when 5
        line.should == 'x\\'
        children.should == []
        completions.should == ['+', 'y']
        block_invocations += 10
        "x+y"
      when 6
        line.should == 'begin'
        children.should == ['b+c', 'x+y']
        completions.should == ['end']
        block_invocations += 100
        'ALL DONE!'
      else
        raise "offset: #{offset.inspect}"
      end
    end
    result.should == 'ALL DONE!'
    size.should == 7
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
    result, size = call expressions do |line, children, completions, offset|
      case offset
      when 2
        [line, children, completions].should == ['    n1 + n2', [], []]
        block_invocations += 1
      when 3
        [line, children, completions].should == ['  [2].map do |n2|', ['    n1 + n2'], ['  end']]
        block_invocations += 10
      when 4
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
    size.should == 5
  end


  example 'example: completions that have children' do
    block_invocations = 0
    expressions = [ "[1].map do |n1|",
                      "[2].map do |n2|",
                        "n1 + n2",
                     "end end",
                  ]
    result, size = call expressions do |line, children, completions, offset|
      case offset
      when 2
        [line, children, completions].should == ["n1 + n2", [], []]
        block_invocations += 1
      when 3
        # not really sure what this *should* be like, but if this is the result,
        # then it will work for the use cases I need it for
        [line, *children, *completions].should == ["[1].map do |n1|",
                                                   "[2].map do |n2|",
                                                   "n1 + n2",
                                                   'end end']
        block_invocations += 10
      else
        raise "offset: #{offset.inspect}"
      end
      [line, *children, *completions].join("\n")
    end
    block_invocations.should == 11
    result.should == "[1].map do |n1|\n"\
                      "[2].map do |n2|\n"\
                        "n1 + n2\n"\
                     "end end"
    size.should == 4
  end

  example 'example: completions who requires its children to be considered for the expression to be valid' do
    block_invocations = 0
    result, size = call ["if true &&", "true", "1", "end"] do |line, children, completions, offset|
      case offset
      when 1
        [line, children, completions].should == ['true', [], []]
        block_invocations += 1
      when 2
        [line, children, completions].should == ['1', [], []]
        block_invocations += 10
      when 3
        [line, children, completions].should == ['if true &&', ['true', '1'], ['end']]
        block_invocations += 100
      end
      [line, *children, *completions].join("\n")
    end
    block_invocations.should == 111
    result.should == "if true &&\ntrue\n1\nend"
    size.should == 4
  end

  example 'example: multiline strings with valid code in them' do
    block_invocations = 0
    call ["'", "1", "'"] do |*expressions, offset|
      expressions.join('').should == "'1'"
      offset.should == 2
      block_invocations += 1
    end
    block_invocations.should == 1
  end

  example 'example: multiline regexps with valid code in them' do
    block_invocations = 0
    call ['/', '1', '/'] do |*expressions, offset|
      expressions.join('').should == "/1/"
      offset.should == 2
      block_invocations += 1
    end
    block_invocations.should == 1
  end

  example "example: =begin/=end comments" do
    block_invocations = 0
    call ['=begin', '1', '=end'] do |*expressions, offset|
      expressions.join('').should == "=begin1=end"
      offset.should == 2
      block_invocations += 1
    end
    block_invocations.should == 1
  end

  example "example: heredoc" do
    pending 'Not sure how to do this, for now just catch it at a higher level' do
      result, size = call ['strings = [<<A, <<-B]', '1', 'A', '2', ' B'] do |*expressions, offset|
        offset.should == 1
        expressions.should == ['strings = [<<A, <<B]']
        'zomg!'
      end
      result.should == "zomg!\n1\nA\n2\n B"
      size.should == 5
    end
  end

  example "example: method invocations on next line" do
    # example 1: consume the expression with lines after
    list = list_for ['a', '.b', ' .c', 'irrelevant'] do |*expressions, offset|
      flat_expressions = expressions.flatten.join('')
      case offset
      when 0
        flat_expressions.should == 'a'
        'A'
      when 1
        flat_expressions.should == 'A.b'
        'A.B'
      when 2
        flat_expressions.should == 'A.B .c'
        'A.B.C'
      else
        raise "O.o"
      end
    end
    list.call.should == ['A.B.C', 3]

    # example 2: consume the expression with no lines after
    list = list_for ['a', '.b'] do |*expressions, offset|
      flat_expressions = expressions.flatten.join('')
      case offset
      when 0
        flat_expressions.should == 'a'
        'A'
      when 1
        flat_expressions.should == 'A.b'
        'A.B'
      else
        raise "O.o"
      end
    end
    list.call.should == ['A.B', 2]
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
        on_complete:    -> { "" },
        get_next_line:  -> { generations.shift },
        peek_next_line: -> { generations.first }
      ).call
    end.to raise_error SyntaxError
  end
end
