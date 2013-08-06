require 'seeing_is_believing/program_rewriter'

# find giant list of keywords, make sure they're all accounted for
# nvm on recording classes/modules/method defs (begin/end that contain them)

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

  describe 'void value expressions' do
    def void_value?(ast)
      klass = described_class.new '', {}
      klass.__send__(:void_value?, ast)
    end

    def ast_for(code)
      Parser::CurrentRuby.parse code
    end

    it 'knows a `return`, `next`, `redo`, `retry`, and `break` are void values' do
      void_value?(ast_for("def a; return; end").children.last).should be_true
      void_value?(ast_for("loop { next  }").children.last).should be_true
      void_value?(ast_for("loop { redo  }").children.last).should be_true
      void_value?(ast_for("loop { break }").children.last).should be_true

      the_retry = ast_for("begin; rescue; retry; end").children.first.children[1].children.last
      the_retry.type.should == :retry
      void_value?(the_retry).should be_true
    end
    it 'knows an `if` is a void value if either side is a void value' do
      the_if = ast_for("def a; if 1; return 2; else; 3; end; end").children.last
      the_if.type.should == :if
      void_value?(the_if).should be_true

      the_if = ast_for("def a; if 1; 2; else; return 3; end; end").children.last
      the_if.type.should == :if
      void_value?(the_if).should be_true

      the_if = ast_for("def a; if 1; 2; else; 3; end; end").children.last
      the_if.type.should == :if
      void_value?(the_if).should be_false
    end
    it 'knows a begin is a void value if its last element is a void value' do
      the_begin = ast_for("loop { begin; break; end }").children.last
      [:begin, :kwbegin].should include the_begin.type
      void_value?(the_begin).should be_true

      the_begin = ast_for("loop { begin; 1; end }").children.last
      [:begin, :kwbegin].should include the_begin.type
      void_value?(the_begin).should be_false
    end
    it 'knows a rescue is a void value if its last child or its else is a void value' do
      the_rescue = ast_for("begin; rescue; retry; end").children.first
      the_rescue.type.should == :rescue
      void_value?(the_rescue).should be_true

      the_rescue = ast_for("begin; rescue; 1; else; retry; end").children.first
      the_rescue.type.should == :rescue
      void_value?(the_rescue).should be_true

      the_rescue = ast_for("begin; rescue; 1; else; 2; end").children.first
      the_rescue.type.should == :rescue
      void_value?(the_rescue).should be_false
    end
    it 'knows an ensure is a void value if its body or ensure portion are void values' do
      the_ensure = ast_for("loop { begin; break; ensure; 1; end }").children.last.children.last
      the_ensure.type.should == :ensure
      void_value?(the_ensure).should be_true

      the_ensure = ast_for("loop { begin; 1; ensure; break; end }").children.last.children.last
      the_ensure.type.should == :ensure
      void_value?(the_ensure).should be_true

      the_ensure = ast_for("loop { begin; 1; ensure; 2; end }").children.last.children.last
      the_ensure.type.should == :ensure
      void_value?(the_ensure).should be_false
    end
    it 'knows other things are not void values' do
      void_value?(ast_for "123").should be_false
    end
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
      wrap("(1\n2)").should == "<(<1>\n2)>"
      wrap("begin\n1\n2\nend").should == "<begin\n<1>\n<2>\nend>"
    end

    it 'does not wrap multiple expressions when they constitute a void value' do
      wrap("def a\n1\nreturn 2\nend").should == "def a\n<1>\nreturn <2>\nend"
      wrap("def a\nreturn 1\n2\nend").should == "def a\n<return <1>\n2>\nend"
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
      # should this actually replace __FILE__ and __LINE__ so as to avoid fucking up values with the rewrite?
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

    it 'wraps ternaries' do
      wrap("1 ? 2 : 3").should == "<1 ? 2 : 3>"
      wrap("1\\\n?\\\n2\\\n:\\\n3").should == "<<1>\\\n?\\\n<2>\\\n:\\\n3>"
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

      wrap("case 1\nwhen 2 then\n3\nwhen 4, 5 then\nelse\n6\nend").should == "<case <1>\nwhen 2 then\n<3>\nwhen 4, 5 then\nelse\n<6>\nend>"
      wrap("case 1\nwhen 2 then\nend").should == "<case <1>\nwhen 2 then\nend>"
      wrap("case\nwhen 2 then\nend").should == "<case\nwhen 2 then\nend>"
      wrap("case\nwhen 2, 3 then\n4\n5\nend").should == "<case\nwhen 2, 3 then\n<<4>\n5>\nend>"
    end

    it 'does not record if the last value in any portion is a void value expression' do
      wrap("def a\nif true\nreturn 1\nend\nend").should == "def a\nif <true>\nreturn <1>\nend\nend"
      wrap("def a\nif true\n1\nelse\nreturn 2\nend\nend").should == "def a\nif <true>\n<1>\nelse\nreturn <2>\nend\nend"
      wrap("def a\nif true\n1\nelsif true\n2\nelse\nreturn 3\nend\nend").should == "def a\nif <true>\n<1>\nelsif <true>\n<2>\nelse\nreturn <3>\nend\nend"
      wrap("def a\nif true\nif true\nreturn 1\nend\nend\nend").should == "def a\nif <true>\nif <true>\nreturn <1>\nend\nend\nend"
      wrap("def a\nunless true\nreturn 1\nend\nend").should == "def a\nunless <true>\nreturn <1>\nend\nend"
      wrap("def a\nunless true\n1\nelse\nreturn 2\nend\nend").should == "def a\nunless <true>\n<1>\nelse\nreturn <2>\nend\nend"
      wrap("def a\ntrue ?\n(return 1) :\n2\nend").should == "def a\n<true> ?\n(return <1>) :\n<2>\nend"
      wrap("def a\ntrue ?\n1 :\n(return 2)\nend").should == "def a\n<true> ?\n<1> :\n(return <2>)\nend"
    end

    # not sure if I actually want this, or if it's just easier b/c it falls out of the current implementation
    it 'wraps the conditional from an inline if, when it cannot wrap the entire if' do
      wrap("def a\nreturn if 1\nend").should == "def a\nreturn if <1>\nend"
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
    it 'wraps for/in loops collections and bodies' do
      wrap("for a in range;1;end").should == "<for a in range;1;end>"
      wrap("for a in range\n1\nend").should == "<for a in <range>\n<1>\nend>"
      wrap("for a,b in whatev\n1\nend").should == "<for a,b in <whatev>\n<1>\nend>"
      # this one just isn't worth it for now, too edge and I'm fucking tired
      # wrap("for char in <<HERE.each_char\nabc\nHERE\nputs char\nend").should ==
      #   "<for char in <<<HERE.each_char>\nabc\nHERE\n<puts char>\nend>"
    end
    it 'does not wrap redo' do
      wrap("loop do\nredo\nend").should == "<loop do\nredo\nend>"
    end
    it 'wraps the value of break' do
      wrap("loop do\nbreak 1\nend").should == "<loop do\nbreak <1>\nend>"
    end
    it 'wraps the value of next' do
      wrap("loop do\nnext 10\nend").should == "<loop do\nnext <10>\nend>"
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
      wrap("1\n<<A\nA").should == "<<1>\n<<A>\nA"
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

  # raises can be safely ignored, they're just method invocations
  describe 'begin/rescue/else/ensure/end blocks' do
    it 'wraps begin/rescue/else/ensure/end blocks' do
      wrap("begin\nrescue\nelse\nensure\nend").should == "<begin\nrescue\nelse\nensure\nend>"
      wrap("begin\nrescue e\ne\nend").should == "<begin\nrescue e\n<e>\nend>"
      wrap("begin\nrescue Exception\n$!\nend").should == "<begin\nrescue Exception\n<$!>\nend>"
    end
    it 'wraps inline rescues' do
      pending "can't figure out how to identify these as different from begin/rescue/end" do
        wrap("1 rescue nil").should == "<1 rescue nil>"
      end
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
      wrap("begin\nend").should == "<begin\nend>"
      wrap("begin\n1\nensure\n2\nend").should == "<begin\n<1>\nensure\n<2>\nend>"
    end
    it 'does not record retry' do
      # in this case, it could record the retry
      # but I don't know how to tell the difference between this and
      # "loop { begin; retry; end }" so w/e
      wrap("begin\nrescue\nretry\nend").should == "begin\nrescue\nretry\nend"
    end
  end

  # eventually, don't wrap these b/c they're spammy, but can be annoying since they can be accidentally recorded
  # by e.g. a begin/end
  # ignoring public/private/protected for now, b/c they're just methods, not keywords
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

  # eventually, don't wrap these b/c they're spammy, but can be annoying since they can be accidentally recorded
  # by e.g. a begin/end
  # ignoring public/private/protected for now, b/c they're just methods, not keywords
  describe 'module definitions' do
    it 'wraps the entire definition and body' do
      wrap("module A\n1\nend").should == "<module A\n<1>\nend>"
    end
    it 'wraps the rescue portion' do
      wrap("module A\n1\nrescue\n2\nend").should == "<module A\n<1>\nrescue\n<2>\nend>"
    end
  end

  describe 'method definitions' do
    it 'does not wrap the definition or arguments' do
      wrap("def a(b,c=1,*d,&e)\nend").should == "def a(b,c=1,*d,&e)\nend"
    end

    it 'wraps the body' do
      wrap("def a\n1\nend").should == "def a\n<1>\nend"
      wrap("def a()\n1\nend").should == "def a()\n<1>\nend"
    end

    it 'wraps calls to yield' do
      wrap("def a\nyield\nend").should == "def a\n<yield>\nend"
    end

    it 'wraps calls to super' do
      wrap("def a\nsuper\nend").should == "def a\n<super>\nend"
    end

    it 'wraps the bodies of returns' do
      wrap("def a\nreturn 1\nend").should == "def a\nreturn <1>\nend"
    end

    it 'wraps the rescue and ensure portion' do
      wrap("def a\n1\nrescue\n2\nend").should == "def a\n<1>\nrescue\n<2>\nend"
      wrap("def a\n1\nrescue\n2\nensure\n3\nend").should == "def a\n<1>\nrescue\n<2>\nensure\n<3>\nend"
      wrap("def a\n1\nensure\n2\nend").should == "def a\n<1>\nensure\n<2>\nend"
    end
  end
end
