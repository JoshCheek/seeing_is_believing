require 'seeing_is_believing'
require 'stringio'

describe SeeingIsBelieving do
  def invoke(input)
    described_class.new(input).call
  end

  def values_for(input)
    invoke(input).to_a.map(&:last)
  end

  def stream(string)
    StringIO.new string
  end

  it 'takes a string or stream and returns a result of the line numbers (counting from 1) and each inspected result from that line' do
    input  = "1+1\n'2'+'2'"
    output = [[1, ["2"]], [2, ['"22"']]]
    invoke(input).to_a.should == output
    invoke(stream input).to_a.should == output
  end

  it 'remembers context of previous lines' do
    values_for("a=12\na*2").should == [['12'], ['24']]
  end

  it 'can be invoked multiple times, returning the same result' do
    believer = described_class.new("$xyz||=1\n$xyz+=1")
    believer.call.to_a.should == [[1, ['1']], [2, ['2']]]
    believer.call.to_a.should == [[1, ['1']], [2, ['2']]]
  end

  it 'is evaluated at the toplevel' do
    values_for('self').should == [['main']]
  end

  it 'records the value immediately, so that it is correct even if the result is mutated' do
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

    values_for("'\n1\n'").should == [[], [], ['"\n1\n"']]

    # fails b/c parens should go around line 1, not around entire expression -.^
    # values_for("<<HEREDOC\n1\nHEREDOC").should == [[], [], ['"\n1\n"']]
    # values_for("<<-HEREDOC\n1\nHEREDOC").should == [[], [], ['"\n1\n"']]
  end

  it 'does not record expressions that end in a comment' do
    values_for("1
                2 # on internal expression
                3 # at end of program").should == [['1'], [], []]
  end

  it 'has no output for empty lines' do
    values_for('').should == [[]]
    values_for('  ').should == [[]]
    values_for("  \n").should == [[]]
    values_for("1\n\n2").should == [['1'],[],['2']]
  end

  it 'stops executing on errors and reports them' do
    invoke("'no exception'").should_not have_exception

    result = invoke("12\nraise Exception, 'omg!'\n12")
    result.should have_exception
    result.exception.message.should == 'omg!'

    result[1].should == ['12']

    result[2].should == []
    result[2].exception.should == result.exception

    result[3].should == []
    result.to_a.size.should == 3

    pending 'Not sure how to force the backtrace to render' do
      result.exception.backtrace.should be_a_kind_of Array
    end
  end

  it 'does not fuck up __LINE__ macro' do
    values_for('__LINE__
                __LINE__

                def meth
                  __LINE__
                end
                meth

                # comment
                __LINE__').should == [['1'], ['2'], [], [], ['5'], ['nil'], ['5'], [], [], ['10']]
  end

  it 'does not try to record a return statement when that will break it' do
    values_for("def meth \n return 1          \n end \n meth").should == [[], [], ['nil'], ['1']]
    values_for("def meth \n return 1 if true  \n end \n meth").should == [[], [], ['nil'], ['1']]
    values_for("def meth \n return 1 if false \n end \n meth").should == [[], [], ['nil'], ['nil']]
    values_for("-> {  \n return 1          \n }.call"        ).should == [[], [], ['1']]
    # this doesn't work because the return detecting code is a very conservative regexp
    # values_for("-> { return 1 }.call"        ).should == [['1']]
  end

  it 'does not affect its environment' do
    invoke 'def Object.abc() end'
    Object.should_not respond_to :abc
  end

  # something about printing to stdout
  # something about printing to stderr
  # something about when the whole input is invalid
  # something about multi-line strings
end
