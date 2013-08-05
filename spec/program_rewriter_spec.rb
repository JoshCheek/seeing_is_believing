require 'seeing_is_believing/program_rewriter'

# find giant list of keywords, make sure they're all accounted for

describe SeeingIsBelieving::ProgramReWriter do
  def wrap(code)
    described_class.call code,
      before_each: -> * { '<' },
      after_each:  -> * { '>' }
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

  it 'ignores comments' do
    wrap("1 #abc\n#def").should == "<1> #abc\n#def"
    wrap("1\n=begin\n2\n=end").should == "<1>\n=begin\n2\n=end"
    wrap("=begin\n1\n=end\n2").should == "=begin\n1\n=end\n<2>"
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

    # many of these taken from http://en.wikibooks.org/wiki/Ruby_Programming/Syntax/Literals
    it 'wraps simple literals' do
      # should maybe also do %i[] and %I[] for symbols,
      # but that's only Ruby 2.0, so I'm ignoring it for now
      # (I expect it to handle them just fine)
      %w|123
         -123
         1_123
         -543
         123_456_789_123_456_789
         123.45
         1.2e-3
         0xaabb
         0377
         -0b1010
         0b001_001

         ?a
         ?\C-a
         ?\M-a
         ?\M-\C-a

         1..2
         1...2

         (true==true)..(1==2)

         true
         false
         nil
         self

         [1,2,3]
         [1,*a,*[2,3,4]]
         %w(1)
         %W(2)

         %x[ls]

         /abc/
         %r(abc)
         %r.abc.

         :abc
         :"abc"
         :'abc'

         {1=>2}
         {a:1}
      |.each do |literal|
        wrap(literal).should == "<#{literal}>"
      end
    end

    it 'wraps macros' do
      # there is also __dir__, but it's only 2.0
      wrap("__FILE__").should == "<__FILE__>"
      wrap("__LINE__").should == "<__LINE__>"
    end
  end

  describe 'variable lookups' do
    it 'wraps them' do
      wrap('a').should == "<a>"
      wrap("$a").should == "<$a>"
      wrap("@a").should == "<@a>"
      wrap("@@a").should == "<@@a>"
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

    it 'wraps operators calls' do
      wrap("1+1").should == "<1+1>"
      wrap("a.b+1").should == "<a.b+1>"
      wrap("a.b - 1").should == "<a.b - 1>"
      wrap("a.b -1").should == "<a.b -1>"
      wrap("!1").should == "<!1>"
      wrap("~1").should == "<~1>"
    end

    it 'wraps methods that end in bangs and questions' do
      wrap("a.b!").should == "<a.b!>"
      wrap("a.b?").should == "<a.b?>"
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

    it 'wraps multiple assignment with splats' do
      wrap("a,* =1,2,3").should == "<a,* =1,2,3>"
    end

    it 'wraps the array equivalent' do
      wrap("a,* =[1,2,3]").should == "<a,* =[1,2,3]>"
      wrap("a,* = [ 1,2,3 ] ").should == "<a,* = [ 1,2,3 ]> "
    end

    it 'wraps repeated assignments' do
      wrap("a=b=1").should == "<a=b=1>"
      wrap("a=b=\n1").should == "<a=b=\n1>"
      wrap("a=\nb=\n1").should == "<a=\nb=\n1>"
    end

    it 'wraps operator assignment' do
      wrap("a += 1").should == "<a += 1>"
      wrap("a *= 1").should == "<a *= 1>"
      wrap("a -= 1").should == "<a -= 1>"
      wrap("a /= 1").should == "<a /= 1>"
      wrap("a **= 1").should == "<a **= 1>"
      wrap("a |= 1").should == "<a |= 1>"
      wrap("a &= 1").should == "<a &= 1>"
      wrap("a ||= 1").should == "<a ||= 1>"
      wrap("a &&= 1").should == "<a &&= 1>"
    end
  end

  describe 'conditionals' do
    it 'wraps if/elsif/else/end, the whole thing, their conditionals, and their bodies' do
      wrap("if 1\n2\nelsif 2\n3\nelsif 4\n5\nend").should == "<if <1>\n<2>\nelsif <2>\n<3>\nelsif <4>\n<5>\nend>" # multiple elsif
      wrap("if 1\n2\nelsif 2\n3\nelse\n4\nend").should == "<if <1>\n<2>\nelsif <2>\n<3>\nelse\n<4>\nend>"         # elisf and else
      wrap("if 1\n2\nelsif 3\n4\nend").should == "<if <1>\n<2>\nelsif <3>\n<4>\nend>"                             # elsif only
      wrap("if 1\n2\nelse\n2\nend").should == "<if <1>\n<2>\nelse\n<2>\nend>"                                     # else only
      wrap("if 1\n2\nend").should == "<if <1>\n<2>\nend>"                                                         # if only

      # same as above, but with then
      wrap("if 1 then\n2\nelsif 2 then\n3\nelsif 4 then\n5\nend").should == "<if <1> then\n<2>\nelsif <2> then\n<3>\nelsif <4> then\n<5>\nend>"
      wrap("if 1 then\n2\nelsif 2 then\n3\nelse\n4\nend").should == "<if <1> then\n<2>\nelsif <2> then\n<3>\nelse\n<4>\nend>"
      wrap("if 1 then\n2\nelsif 3 then\n4\nend").should == "<if <1> then\n<2>\nelsif <3> then\n<4>\nend>"
      wrap("if 1 then\n2\nelse\n2\nend").should == "<if <1> then\n<2>\nelse\n<2>\nend>"
      wrap("if 1 then\n2\nend").should == "<if <1> then\n<2>\nend>"

      # inline
      wrap("1 if 2").should == "<1 if 2>"
    end

    it 'wraps "unless" statements' do
      wrap("unless 1\n2\nelse\n3\nend").should == "<unless <1>\n<2>\nelse\n<3>\nend>"
      wrap("unless 1\n2\nend").should == "<unless <1>\n<2>\nend>"
      wrap("unless 1 then\n2\nelse\n3\nend").should == "<unless <1> then\n<2>\nelse\n<3>\nend>"
      wrap("unless 1 then\n2\nend").should == "<unless <1> then\n<2>\nend>"
      wrap("1 unless 2").should == "<1 unless 2>"
    end

    it 'wraps case statements, and the value they are initialized with, but not the conditionals' do
      wrap("case 1\nwhen 2\n3\nwhen 4, 5\nelse\n6\nend").should == "<case <1>\nwhen 2\n<3>\nwhen 4, 5\nelse\n<6>\nend>"
      wrap("case 1\nwhen 2\nend").should == "<case <1>\nwhen 2\nend>"
      wrap("case\nwhen 2\nend").should == "<case\nwhen 2\nend>"
      wrap("case\nwhen 2, 3\n4\n5\nend").should == "<case\nwhen 2, 3\n<<4>\n5>\nend>"
    end
  end

  describe 'loops' do
    it 'wraps the until condition and body' do
      wrap("until 1\n2\nend").should == "<until <1>\n<2>\nend>"
      wrap("1 until 2").should == "<1 until 2>"
    end
    it 'wraps the while condition and body' do
      wrap("while 1\n2\nend").should == "<while <1>\n<2>\nend>"
      wrap("1 while 2").should == "<1 while 2>"
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

    it 'records %, %q, %Q' do
      wrap('%(A)').should == '<%(A)>'
      wrap('%.A.').should == '<%.A.>'
      wrap('%q(A)').should == '<%q(A)>'
      wrap('%q.A.').should == '<%q.A.>'
      wrap('%Q(A)').should == '<%Q(A)>'
      wrap('%Q.A.').should == '<%Q.A.>'
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

    it 'records methods tacked onto the end of heredocs' do
      wrap("<<A.size\nA").should == "<<<A.size>\nA"
      wrap("<<A.whatever <<B\nA\nB").should == "<<<A.whatever <<B>\nA\nB"
      wrap("<<A.whatever(<<B)\nA\nB").should == "<<<A.whatever(<<B)>\nA\nB"
      wrap("<<A.size()\nA").should == "<<<A.size()>\nA"
    end
  end

  describe 'begin/rescue/else/ensure/end blocks' do
    it 'wraps begin/rescue/else/ensure/end blocks' do
      wrap("begin\nrescue\nelse\nensure\nend").should == "<begin\nrescue\nelse\nensure\nend>"
    end
    it 'wraps the bodies' do
      wrap("begin\n1\nrescue\n2\nelse\n3\nensure\n4\nend").should ==
        "<begin\n<1>\nrescue\n<2>\nelse\n<3>\nensure\n<4>\nend>"
    end
    it 'wraps bodies with various pieces missing' do
      wrap("begin\n1\nrescue\n2\nelse\n3\nensure\n4\nend").should == "<begin\n<1>\nrescue\n<2>\nelse\n<3>\nensure\n<4>\nend>"
      wrap("begin\n1\nrescue\n2\nelse\n3\nend").should == "<begin\n<1>\nrescue\n<2>\nelse\n<3>\nend>"
      wrap("begin\n1\nrescue\n2\nend").should == "<begin\n<1>\nrescue\n<2>\nend>"
      wrap("begin\n1\nend").should == "<begin\n<1>\nend>"
      wrap("begin\n1\nensure\n2\nend").should == "<begin\n<1>\nensure\n<2>\nend>"
    end
  end

  describe 'class definitions' do
    it 'wraps the entire definition and body' do
      wrap("class A\n1\nend").should == "<class A\n<1>\nend>"
    end

    it 'wraps the superclass' do
      wrap("class A < B\nend").should == "<class A < <B>\nend>"
    end

    it 'wraps the rescue portion' do
      wrap("class A < B\n1\nrescue\n2\nend").should == "<class A < <B>\n<1>\nrescue\n<2>\nend>"
    end
  end

  describe 'module definitions' do
    it 'wraps the entire definition and body' do
      wrap("module A\n1\nend").should == "<module A\n<1>\nend>"
    end
    it 'wraps the rescue portion' do
      wrap("module A\n1\nrescue\n2\nend").should == "<module A\n<1>\nrescue\n<2>\nend>"
    end
  end
end
