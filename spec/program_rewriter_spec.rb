require 'seeing_is_believing/program_rewriter'


# a,b=*
# a,b=1,\n2
describe SeeingIsBelieving::ProgramReWriter do
  def wrap(code)
    described_class.call code,
      before_each: -> * { '<' },
      after_each:  -> * { '>' }
  end

  describe 'basic expressions' do
    it 'wraps an expression' do
      wrap("A").should == "<A>"
    end

    it 'wraps multiple expressions' do
      # so why not (A)\n(A)?
      # because multiple expressions get implicit begin/end blocks around them
      # and the begin/end block ends on the same line as the second expression
      # this is fine, though, as it will evaluate to the same value
      wrap("A\nB").should == "<<A>\nB>"
    end

    it 'wraps nested expressions' do
      wrap("A do\nB\nend").should == "<A do\n<B>\nend>"
    end

    it 'wraps multiple expressions on the same line' do
      wrap("a;b").should == "<a;b>"
    end
  end

  describe 'method invocations' do
    it 'wraps the whole invocation with or without parens' do
      wrap("a").should == "<a>"
      wrap("a()").should == "<a()>"
      wrap("a()").should == "<a()>"
    end

    it 'does not wrap arguments' do
      wrap("a b").should == "<a b>"
      wrap("a(b,c=1,*d,&e)").should == "<a(b,c=1,*d,&e)>"
    end

    it 'wraps blocks' do
      wrap("a { }").should == "<a { }>"
      wrap("a {\n}").should == "<a {\n}>"
      wrap("a(b) {\n}").should == "<a(b) {\n}>"
    end

    it 'wraps method calls with an explicit receiver' do
      wrap("1.mod(2)").should == "<1.mod(2)>"
      wrap("1.mod 2").should == "<1.mod 2>"
    end

    # TODO: More of these probably
    it 'wraps operators calls' do
      wrap("1+1").should == "<1+1>"
      wrap("a.b+1").should == "<a.b+1>"
      wrap("!1").should == "<!1>"
      wrap("~1").should == "<~1>"
    end

    it 'wraps method invocations that span multiple lines' do
      wrap("a\n.b\n.c").should == "<<<a>\n.b>\n.c>"
    end

    it 'wraps args in method arguments when the method spans multiple lines' do
      wrap("a 1,\n2").should == "<a <1>,\n2>"
    end
  end

  describe 'assignment' do
    it 'wraps entire simple assignment' do
      wrap("a=1").should == "<a=1>"
    end

    it 'wraps multiple assignments' do
      wrap("a,b=1,2").should == "<a,b=1,2>"
    end

    it 'wraps multiple assignment on each line' do
      wrap("a,b=1,\n2").should == "<a,b=<1>,\n2>"
    end

    it 'wraps multiple assignment with splats', t:true do
      wrap("a,* =1,2,3").should == "<a,* =1,2,3>"
    end

    it 'wraps the array equivalent', t:true do
      wrap("a,* =[1,2,3]").should == "<a,* =[1,2,3]>"
      wrap("a,* = [ 1,2,3 ] ").should == "<a,* = [ 1,2,3 ]> "
    end

    it 'wraps repeated assignments' do
      wrap("a=b=1").should == "<a=b=1>"
      wrap("a=b=\n1").should == "<a=b=\n1>"
      wrap("a=\nb=\n1").should == "<a=\nb=\n1>"
    end
  end

  describe 'constant access' do
    it 'wraps simple constant access' do
      wrap("A").should == "<A>"
    end

    it 'wraps namespaced constant access' do
      wrap("::A").should == "<::A>"
      wrap("A::B").should == "<A::B>"
    end
  end

  describe 'string literals (except heredocs)' do
    it 'records single and double quoted strings' do
      wrap("'a'").should == "<'a'>"
      wrap('"a"').should == '<"a">'
    end

    it 'records strings with %, %Q, and %q' do
      wrap("%'a'").should == "<%'a'>"
      wrap("%q'a'").should == "<%q'a'>"
      wrap("%Q'a'").should == "<%Q'a'>"
    end

    it 'records strings that span mulitple lines' do
      wrap("'a\nb'").should == "<'a\nb'>"
      wrap(%'"a\nb"').should == %'<"a\nb">'
    end

    # eventually it would be nice if it recorded the interpolated portion,
    # when the end of the line was not back inside the string
    it 'records strings with interpolation, but not the interpolated portion' do
      wrap('"a#{1}"').should == '<"a#{1}">'
      wrap(%'"a\n\#{1}\nb"').should == %'<"a\n\#{1}\nb">'
      wrap(%'"a\n\#{1\n}b"').should == %'<"a\n\#{1\n}b">'
    end

    it 'records methods tacked onto the end of heredocs' do
      wrap("<<A.size\nA").should == "<<<A.size>\nA"
      wrap("<<A.whatever <<B\nA\nB").should == "<<<A.whatever <<B>\nA\nB"
      wrap("<<A.whatever(<<B)\nA\nB").should == "<<<A.whatever(<<B)>\nA\nB"
      wrap("<<A.size()\nA").should == "<<<A.size()>\nA"
    end
  end

  describe 'heredocs' do
    it 'records heredocs on their first line' do
      wrap("<<A\nA").should == "<<<A>\nA"
      wrap("<<-A\nA").should == "<<<-A>\nA"
    end

    it "records methods that wrap heredocs, even whent hey don't have parentheses" do
      wrap("a(<<HERE)\nHERE").should == "<a(<<HERE)>\nHERE"
      wrap("a <<HERE\nHERE").should == "<a <<HERE>\nHERE"
      wrap("a 1, <<HERE\nHERE").should == "<a 1, <<HERE>\nHERE"
      wrap("a.b 1, 2, <<HERE1, <<-HERE2 \nHERE1\n HERE2").should ==
          "<a.b 1, 2, <<HERE1, <<-HERE2> \nHERE1\n HERE2"
      wrap("a.b 1,\n2,\n<<HERE\nHERE").should == "<a.b <1>,\n<2>,\n<<HERE>\nHERE"
    end

    it "records assignments whose value is a heredoc" do
      wrap("a=<<A\nA").should == "<a=<<A>\nA"
      wrap("a,b=<<A,<<B\nA\nB").should == "<a,b=<<A,<<B>\nA\nB"
      wrap("a,b=1,<<B\nB").should == "<a,b=1,<<B>\nB"
      wrap("a,b=<<A,1\nA").should == "<a,b=<<A,1>\nA"
    end
  end

  describe 'begin/rescue/end blocks' do
    it 'wraps begin/rescue/end blocks'
  end

  describe 'class definitions' do
    it 'wraps the entire definition' do
      wrap("class A\nend").should == "<class A\nend>"
    end

    it 'wraps the superclass' do
      wrap("class A < B\nend").should == "<class A < <B>\nend>"
    end
  end

  describe 'module definitions' do
    it 'wraps the entire definition' do
      wrap("module A\nend").should == "<module A\nend>"
    end
  end

  it 'wraps the entire body, ignoring leading comments and the data segment' do
    described_class.call("#comment\nA\n__END__\n1",
                         before_all: "[",
                         after_all:  "]",
                         before_each: -> * { '<' },
                         after_each:  -> * { '>' }
                        )
                   .should == "#comment\n[<A>]\n__END__\n1"
  end

  it 'passes the current line number to the before_each and after_each wrappers' do
    pre_line_num = post_line_num = nil
    described_class.call("\na",
                         before_each: -> _pre_line_num  { pre_line_num  = _pre_line_num;  '<' },
                         after_each:  -> _post_line_num { post_line_num = _post_line_num; '>' }
                        )
    pre_line_num.should == 2
    post_line_num.should == 2
  end

end
