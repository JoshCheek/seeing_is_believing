require 'seeing_is_believing/binary/comment_lines'

# FIXME: For now ignoring heredocs
#        because we know the user of this class won't have output on them
#        and it's a PITA to deal with.
#        Eventually, though, Parser should take this into account
describe SeeingIsBelieving::Binary::CommentLines, 'passes in the each commentable line and the line number, and adds the returned text (whitespace+comment) to the end' do
  def call(code, &block)
    described_class.call code, &block
  end

  it "doesn't comment lines whose newline is escaped" do
    call("1 +\\\n2") { |_, line_number| "--#{line_number}--" }.should == "1 +\\\n2--2--"
  end

  it "doesn't comment lines inside of strings" do
    call(<<-INPUT) { |_, line_number| "--#{line_number}--" }.should == <<-OUTPUT
    "a\#{1+1
    }"
    "a
     b"
    'a
     b'
    %Q{
      }
    %q{
      }
    %.
     .
    INPUT
    "a\#{1+1
    }"--2--
    "a
     b"--4--
    'a
     b'--6--
    %Q{
      }--8--
    %q{
      }--10--
    %.
     .--12--
    OUTPUT
  end

  it "doesn't comment lines inside of regexes" do
    call(<<-INPUT) { |_, line_number| "--#{line_number}--" }.should == <<-OUTPUT
    /a\#{1+1
    }/
    /a
     b/ix
    %r.
      .
    INPUT
    /a\#{1+1
    }/--2--
    /a
     b/ix--4--
    %r.
      .--6--
    OUTPUT
  end

  it "doesn't comment lines inside of backticks/%x" do
    call(<<-INPUT) { |_, line_number| "--#{line_number}--" }.should == <<-OUTPUT
    `a\#{1+1
    }`
    %x[\#{1+1
    }]
    `
     b
     c`
    %x.
       b
       c.
    INPUT
    `a\#{1+1
    }`--2--
    %x[\#{1+1
    }]--4--
    `
     b
     c`--7--
    %x.
       b
       c.--10--
    OUTPUT
  end

  it "doesn't comment lines inside of string arrays" do
    call(<<-INPUT) { |_, line_number| "--#{line_number}--" }.should == <<-OUTPUT
    %w[
      a
      ]
    INPUT
    %w[
      a
      ]--3--
    OUTPUT
  end


  it 'yields the line and line number to the commenter block' do
    lines = []
    result = call("1 +\n"\
                  "    2\n"\
                  "\n"\
                  "# just a comment\n"\
                  "3 # already has a comment\n"\
                  "'4\n"\
                  "5'+\n"\
                  "%Q'\n"\
                  " \#{5+6} 7'\n") do |line, line_number|
      lines << line
      "--#{line_number}--"
    end

    lines.should == [ "1 +",
                      "    2",
                      "",
                      "5'+",
                      " \#{5+6} 7'"]

    result.should == "1 +--1--\n"\
                     "    2--2--\n"\
                     "--3--\n"\
                     "# just a comment\n"\
                     "3 # already has a comment\n"\
                     "'4\n"\
                     "5'+--7--\n"\
                     "%Q'\n"\
                     " \#{5+6} 7'--9--\n"
  end


  example 'big comprehensive example' do
input=<<INPUT
# comment
1 # comment after line
=begin
multiline comment
=end

1;

class A
end
A

class B < A
  def m
  end
  def m1(a, b=1, *c, d, &e)
  end
  def m2() 1
  end
  def m3(a,
         b)
  end

  public
  private
  protected
  class << self
    1
    super
    yield
    return 2
    return
  rescue
    3
  ensure
    4
  end
end

module C
  include Comparable
  extend Comparable
end

a
a.b
a.b 1
b 2
b 2, 3
b(2, 3)
b(2, 3) { |a| }
a { }
b { |a|
}
b do |arg| end
b do |arg|
end

-> a {
}
-> { }.()

123
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
?\\C-a
?\\M-a
?\\M-\\C-a
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
:'abc'
:"abc"
:"a\#{1}"
{1=>2}
{a:1}
__FILE__
__LINE__
defined? a

# some void values
loop {
  next
}
loop {
  redo
}
loop {
  break
}

# conditionals
1 if a
if a
end
if (a)
end
if (a &&
    b)
end
if a == b
  1
elsif b != c
  2
else
  3
  4
end
unless a && b || c
  1
else
  2
end
1 ? 2 : 3
1 ?
2 :
3

# begin/rescue/end
begin
  1
rescue
  2
rescue => a
  3
rescue Exception
  4
rescue Exception => a
  5
else
  6
ensure
  7
end
1 rescue nil

(a
 b)
(a
 b
)
a;b
alias a b
undef whatev
`a`
`a
 b`
`a \#{
123
}
`
%x[
a
\#{
123
}
b
]
$a
@a
@@a

a
a()
a.b
a.b!
a.b?
a.b()
a b
a(b,c,*d,&e)
a b,c,*d,&e
a b,c,*d do
end
a.b c,d,*e do
end
a.b(c,d,*e) { }
a.b {
123
}
1+1
a.b+1
a.b-1
a.b - 1
!1
~1
a.b 1,
    2,
    3 => 4
a.b(
    1,
    2)
a { |
     b|
    }
a=1
a.b=1
A
A=1
A::B
A::B=1
@a=1
@@a=1
$a=1
a,@b=1,2
a=
1
a=b=1
a += 1
a *= 1
a -= 1
a /= 1
a **= 1
a |= 1
a &= 1
a ||= 1
a &&= 1
a[1] = 2
a[1] ||= 2
a[
1,
2] = 3
1 if /abc/
case a
when b
  1
when c then d
  2
else
  3
end
if 1 and
   2 or
   3
  3
end
if 1 then
  2
end

1 until 2
1 while 2
until 1
 2
end
while 1
  2
end
for a in [1,2,3]
  redo
end
for a in [1,2,3] do
  redo
  break
  break 10
  next
  next 10
end
{1 =>
     2,
 3 => 4,
 a:
   1,
 b: 2,
}
puts(a: b)
puts a: b
[1,
 2,
 *abc
]

/a
 \#{
 123
 }/x
%r.1
   2
   .i

"a
 b"
"a\#{
123
}
\#{123}"
'a
 b'
%.
a\#{
123
}.
%Q.
a\#{
123
}.
%q.
  1
  .
INPUT

output=<<OUTPUT
# comment
1 # comment after line
=begin
multiline comment
=end
;
1;;
;
class A;
end;
A;
;
class B < A;
  def m;
  end;
  def m1(a, b=1, *c, d, &e);
  end;
  def m2() 1;
  end;
  def m3(a,;
         b);
  end;
;
  public;
  private;
  protected;
  class << self;
    1;
    super;
    yield;
    return 2;
    return;
  rescue;
    3;
  ensure;
    4;
  end;
end;
;
module C;
  include Comparable;
  extend Comparable;
end;
;
a;
a.b;
a.b 1;
b 2;
b 2, 3;
b(2, 3);
b(2, 3) { |a| };
a { };
b { |a|;
};
b do |arg| end;
b do |arg|;
end;
;
-> a {;
};
-> { }.();
;
123;
-123;
1_123;
-543;
123_456_789_123_456_789;
123.45;
1.2e-3;
0xaabb;
0377;
-0b1010;
0b001_001;
?a;
?\\C-a;
?\\M-a;
?\\M-\\C-a;
1..2;
1...2;
(true==true)..(1==2);
true;
false;
nil;
self;
[1,2,3];
[1,*a,*[2,3,4]];
%w(1);
%W(2);
%x[ls];
/abc/;
%r(abc);
%r.abc.;
:abc;
:'abc';
:"abc";
:"a\#{1}";
{1=>2};
{a:1};
__FILE__;
__LINE__;
defined? a;
;
# some void values
loop {;
  next;
};
loop {;
  redo;
};
loop {;
  break;
};
;
# conditionals
1 if a;
if a;
end;
if (a);
end;
if (a &&;
    b);
end;
if a == b;
  1;
elsif b != c;
  2;
else;
  3;
  4;
end;
unless a && b || c;
  1;
else;
  2;
end;
1 ? 2 : 3;
1 ?;
2 :;
3;
;
# begin/rescue/end
begin;
  1;
rescue;
  2;
rescue => a;
  3;
rescue Exception;
  4;
rescue Exception => a;
  5;
else;
  6;
ensure;
  7;
end;
1 rescue nil;
;
(a;
 b);
(a;
 b;
);
a;b;
alias a b;
undef whatev;
`a`;
`a
 b`;
`a \#{
123
}
`;
%x[
a
\#{
123
}
b
];
$a;
@a;
@@a;
;
a;
a();
a.b;
a.b!;
a.b?;
a.b();
a b;
a(b,c,*d,&e);
a b,c,*d,&e;
a b,c,*d do;
end;
a.b c,d,*e do;
end;
a.b(c,d,*e) { };
a.b {;
123;
};
1+1;
a.b+1;
a.b-1;
a.b - 1;
!1;
~1;
a.b 1,;
    2,;
    3 => 4;
a.b(;
    1,;
    2);
a { |;
     b|;
    };
a=1;
a.b=1;
A;
A=1;
A::B;
A::B=1;
@a=1;
@@a=1;
$a=1;
a,@b=1,2;
a=;
1;
a=b=1;
a += 1;
a *= 1;
a -= 1;
a /= 1;
a **= 1;
a |= 1;
a &= 1;
a ||= 1;
a &&= 1;
a[1] = 2;
a[1] ||= 2;
a[;
1,;
2] = 3;
1 if /abc/;
case a;
when b;
  1;
when c then d;
  2;
else;
  3;
end;
if 1 and;
   2 or;
   3;
  3;
end;
if 1 then;
  2;
end;
;
1 until 2;
1 while 2;
until 1;
 2;
end;
while 1;
  2;
end;
for a in [1,2,3];
  redo;
end;
for a in [1,2,3] do;
  redo;
  break;
  break 10;
  next;
  next 10;
end;
{1 =>;
     2,;
 3 => 4,;
 a:;
   1,;
 b: 2,;
};
puts(a: b);
puts a: b;
[1,;
 2,;
 *abc;
];
;
/a
 \#{
 123
 }/x;
%r.1
   2
   .i;
;
"a
 b";
"a\#{
123
}
\#{123}";
'a
 b';
%.
a\#{
123
}.;
%Q.
a\#{
123
}.;
%q.
  1
  .;
OUTPUT

    call(input) { ';' }.should == output
  end
end
