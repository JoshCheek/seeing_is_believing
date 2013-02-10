# -*- coding: utf-8 -*-
require 'seeing_is_believing'
require 'stringio'

describe SeeingIsBelieving do
  def invoke(input, options={})
    described_class.new(input, options).call
  end

  def values_for(input)
    invoke(input).to_a.map(&:last)
  end

  def stream(string)
    StringIO.new string
  end

  let(:proving_grounds_dir) { File.expand_path '../../proving_grounds', __FILE__ }

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

  it "does not record expressions that are here docs (only really b/c it's not smart enough)" do
    values_for("<<A\n1\nA").should be_all &:empty?
    values_for(" <<A\n1\nA").should be_all &:empty?
    values_for("<<-A\n1\n A").should be_all &:empty?
    values_for(" <<-A\n1\n A").should be_all &:empty?
    values_for("s=<<-A\n1\n A").should be_all &:empty?
    values_for("def meth\n<<-A\n1\nA\nend").should == [[], [], [], [], ['nil']]
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
  end

  it 'records the backtrace on the errors' do
    result = invoke("12\nraise Exception, 'omg!'\n12")
    result.exception.backtrace.should be_a_kind_of Array
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

  it 'captures the standard output and error' do
    result = invoke "2.times { puts 'a', 'b' }
                     STDOUT.puts 'c'
                     $stdout.puts 'd'
                     STDERR.puts '1', '2'
                     $stderr.puts '3'
                     $stdout = $stderr
                     puts '4'"
    result.stdout.should == "a\nb\n" "a\nb\n" "c\n" "d\n"
    result.stderr.should == "1\n2\n" "3\n" "4\n"
    result.should have_stdout
    result.should have_stderr

    result = invoke '1+1'
    result.should_not have_stdout
    result.should_not have_stderr
  end

  it 'defaults the filename to temp_dir/program.rb' do
    result = invoke('print File.expand_path __FILE__')
    File.basename(result.stdout).should == 'program.rb'
  end

  it 'can be told to run as a given file (in a given dir/with a given filename)' do
    filename = File.join proving_grounds_dir, 'mah_file.rb'
    FileUtils.rm_f filename
    result   = invoke 'print File.expand_path __FILE__', filename: filename
    result.stdout.should == filename
  end

  # this can be refactored to use invoke
  specify 'cwd is the directory of the file' do
    filename = File.join proving_grounds_dir, 'mah_file.rb'
    FileUtils.rm_f filename
    result   = invoke 'print File.expand_path __FILE__', filename: filename
    result   = invoke 'print File.expand_path(Dir.pwd)', filename: filename
    result.stdout.should == proving_grounds_dir
  end

  it 'does not capture output from __END__ onward' do
    values_for("1+1\nDATA.read\n__END__\n....").should == [['2'], ['"...."']]
  end

  it 'raises a SyntaxError when the whole program is invalid' do
    expect { invoke '"' }.to raise_error SyntaxError
  end

  it 'can be given a stdin stream' do
    invoke('$stdin.read', stdin: StringIO.new("input"))[1].should == ['"input"']
  end

  it 'can be given a stdin string' do
    invoke('$stdin.read', stdin: "input")[1].should == ['"input"']
  end

  it 'defaults the stdin stream to an empty string' do
    invoke('$stdin.read')[1].should == ['""']
  end

  it 'can deal with methods that are invoked entirely on the next line' do
    values_for("1\n.even?").should == [[], ['false']]
    values_for("1\n.even?\n__END__").should == [[], ['false']]
  end

  it 'does not record leading comments', wip:true do
    values_for("# -*- coding: utf-8 -*-\n'ç'").should == [[], ['"ç"']]
    # values_for("=begin\n1\n=end\n1").should == [[], [], [], ['1']]
  end
end
