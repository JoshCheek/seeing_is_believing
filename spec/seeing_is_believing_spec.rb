# -*- coding: utf-8 -*-
require 'spec_helper'
require 'seeing_is_believing'
require 'stringio'

describe SeeingIsBelieving do
  def invoke(input, options={})
    if options[:debug]
      options.delete :debug
      options[:debugger] = SeeingIsBelieving::Debugger.new(stream: $stderr, colour: true)
    end
    described_class.new(input, options).call
  end

  def values_for(input, options={})
    invoke(input, options).to_a
  end

  let(:proving_grounds_dir) { File.expand_path '../../proving_grounds', __FILE__ }

  it 'takes a string and returns a result of the line numbers (counting from 1) and each inspected result from that line' do
    input  = "10+10\n'2'+'2'"
    expect(invoke(input)[1]).to eq ["20"]
    expect(invoke(input)[2]).to eq ['"22"']
  end

  it 'only invokes inspect once' do
    pending 'Need to make the producer smarter (ie call the block, rather than invoking inspect)'
    input = "class Fixnum; def inspect; 'NUM'\nend\nend\n1"
    expect(invoke(input)[1]).to eq ['"NUM"']
  end

  it 'allows uers to override WrapExpressions initialization keys' do
    expect(invoke(':body', before_all: 'if true;',  after_all: ';end;')[1]).to eq [':body']
    expect(invoke(':body', before_all: 'if false;', after_all: ';end;')[1]).to eq []

    result = invoke ':body', before_each: -> line_number { "$SiB.record_result(:inspect, #{line_number*200}, (" },
                             after_each:  -> line_number { ").to_s.upcase + #{line_number}.inspect)" }
    expect(result[200, :inspect]).to eq ['"BODY1"']
  end

  it 'remembers context of previous lines' do
    expect(values_for("a=12\na*2")).to eq [['12'], ['24']]
  end

  it 'can be invoked multiple times, returning the same result' do
    believer = described_class.new("$xyz||=1\n$xyz+=1")
    expect(believer.call.to_a).to eq [['1'], ['2']]
    expect(believer.call.to_a).to eq [['1'], ['2']]
  end

  it 'is evaluated at the toplevel' do
    expect(values_for('self')).to eq [['main']]
  end

  it 'records the value immediately, so that it is correct even if the result is mutated' do
    expect(values_for("a = 'a'\na << 'b'")).to eq [['"a"'], ['"ab"']]
  end

  it 'records each value when a line is evaluated multiple times' do
    expect(values_for("(1..2).each do |i|\ni\nend")).to eq [['1..2'], ['1', '2'], ['1..2']]
  end

  # now that we're using Parser, there's very very few of these
  it 'evalutes to an empty array for lines that it cannot understand' do
    expect(values_for("[3].map \\\ndo |n|\n n*2\n end")).to eq [['[3]'], [], ['6'], ['[6]']]
    expect(values_for("'\n1\n'")).to eq [[], [], ['"\n1\n"']]
    expect(values_for("<<HEREDOC\n\n1\nHEREDOC")).to eq  [[%Q'"\\n1\\n"']] # newlines escaped b/c lib inspects them
    expect(values_for("<<-HEREDOC\n\n1\nHEREDOC")).to eq [[%Q'"\\n1\\n"']]
  end

  it 'records the targets of chained methods' do
    expect(values_for("[*1..5]\n.map { |n| n * 2 }\n.take(2)\n.size")).to eq\
      [["[1, 2, 3, 4, 5]"], ["[2, 4, 6, 8, 10]"], ["[2, 4]"], ["2"]]
  end

  it 'does not add additional vars' do
    expect(values_for 'local_variables').to eq [["[]"]]
  end

  it "records heredocs" do
    expect(values_for("<<A\n1\nA")).to eq [[%'"1\\n"']]
    expect(values_for("<<-A\n1\nA")).to eq [[%'"1\\n"']]
  end

  it 'does not insert code into the middle of heredocs' do
    invoked = invoke(<<-HEREDOC.gsub(/^      /, ''))
      puts <<DOC1
      doc1
      DOC1
      puts <<-DOC2
      doc2
      DOC2
      puts <<-DOC3
      doc3
        DOC3
      puts <<DOC4, <<-DOC5
      doc4
      DOC4
      doc5
      DOC5
    HEREDOC

    expect(invoked.stdout).to eq "doc1\ndoc2\ndoc3\ndoc4\ndoc5\n"
  end

  it 'has no output for empty lines' do
    expect(values_for('')).to eq [[]]
    expect(values_for('  ')).to eq [[]]
    expect(values_for("  \n")).to eq [[]]
    expect(values_for("1\n\n2")).to eq [['1'],[],['2']]
  end

  it 'stops executing on errors and reports them' do
    expect(invoke("'no exception'")).to_not have_exception

    result = invoke("12\nraise Exception, 'omg!'\n12")
    expect(result).to have_exception
    expect(result.exception.message).to eq 'omg!'

    expect(result[1]).to eq ['12']
    expect(result[2]).to eq []
    expect(result[3]).to eq []
  end

  it 'records the backtrace on the errors' do
    result = invoke("12\nraise Exception, 'omg!'\n12")
    expect(result.exception.backtrace).to be_a_kind_of Array
  end

  it 'does not fuck up __LINE__ macro' do
    expect(values_for( '__LINE__
                        __LINE__

                        def meth
                          __LINE__
                        end
                        meth

                        # comment
                        __LINE__')
    ).to eq [['1'], ['2'], [], [], ['5'], [], ['5'], [], [], ['10']]
  end

  it 'records return statements' do
    expect(values_for("def meth \n return 1          \n end \n meth")).to eq [[], ['1'], [], ['1']]
    expect(values_for("-> {  \n return 1          \n }.call"        )).to eq [[], ['1'], ['1']]
    expect(values_for("-> { return 1 }.call"                        )).to eq [['1']]

    pending "would be really cool if this would record 1 and nil, but it probably won't ever happen."
    # Currently we dont' differentiate between inline and multiline if statements,
    # also, we can't wrap the whole statement since it's void value, which means we'd have to introduce
    # the idea of multiple wrappings for the same line, which I just don't care enough about to consider
    expect(values_for("def meth \n return 1 if true  \n end \n meth")).to eq [[], ['1'], [], ['1']]   # records true instead of 1
    expect(values_for("def meth \n return 1 if false \n end \n meth")).to eq [[], ['nil'], [], ['nil']] # records false instead of nil
  end

  it 'does not try to record the keyword next' do
    expect(values_for("(1..2).each do |i|\nnext if i == 1\ni\nend")).to eq [['1..2'], ['true', 'false'], ['2'], ['1..2']]
  end

  it 'does not try to record the keyword redo' do
    expect(values_for(<<-DOC)).to eq [[], ['0'], ['0...3'], ['1', '2', '3', '4'], ['false', 'true', 'false', 'false'], ['0...3'], [], ['0...3']]
      def meth
        n = 0
        for i in 0...3
          n += 1
          redo if n == 2
        end
      end
      meth
    DOC
  end

  it 'does not try to record the keyword retry' do
    expect(values_for(<<-DOC)).to eq [[], [], [], [], ['nil']]
      def meth
      rescue
        retry
      end
      meth
    DOC
  end

  it 'does not try to record the keyword retry' do
    expect(values_for(<<-DOC)).to eq [['0..2'], ['0'], [], ['nil']]
      (0..2).each do |n|
        n
        break
      end
    DOC
    expect(values_for(<<-DOC)).to eq [['0..2'], ['0'], ['10'], ['10']]
      (0..2).each do |n|
        n
        break 10
      end
    DOC
  end

  it 'does not affect its environment' do
    invoke 'def Object.abc() end'
    expect(Object).to_not respond_to :abc
  end

  it 'captures the standard output and error' do
    result = invoke "2.times { puts 'a', 'b' }
                     STDOUT.puts 'c'
                     $stdout.puts 'd'
                     STDERR.puts '1', '2'
                     $stderr.puts '3'
                     $stdout = $stderr
                     puts '4'"
    expect(result.stdout).to eq "a\nb\n" "a\nb\n" "c\n" "d\n"
    expect(result.stderr).to eq "1\n2\n" "3\n" "4\n"
    expect(result).to have_stdout
    expect(result).to have_stderr

    result = invoke '1+1'
    expect(result).to_not have_stdout
    expect(result).to_not have_stderr
  end

  it 'defaults the filename to temp_dir/program.rb' do
    result = invoke('print File.expand_path __FILE__')
    expect(File.basename(result.stdout)).to eq 'program.rb'
  end

  it 'can be told to run as a given file (in a given dir/with a given filename)' do
    filename = File.join proving_grounds_dir, 'mah_file.rb'
    FileUtils.rm_f filename
    result   = invoke 'print File.expand_path __FILE__', filename: filename
    expect(result.stdout).to eq filename
  end

  specify 'cwd of the file is the cwd of the evaluating program' do
    filename = File.join proving_grounds_dir, 'mah_file.rb'
    FileUtils.rm_f filename
    expect(invoke('print File.expand_path(Dir.pwd)', filename: filename).stdout).to eq Dir.pwd
  end

  it 'does not capture output from __END__ onward' do
    expect(values_for("1+1\nDATA.read\n__END__\n....")).to eq [['2'], ['"....\n"']] # <-- should this actually write a newline on the end?
  end

  it 'raises a SyntaxError when the whole program is invalid' do
    expect { invoke '"' }.to raise_error SyntaxError
  end

  it 'can be given a stdin stream' do
    expect(invoke('$stdin.read', stdin: StringIO.new("input"))[1]).to eq ['"input"']
  end

  it 'can be given a stdin string' do
    expect(invoke('$stdin.read', stdin: "input")[1]).to eq ['"input"']
  end

  it 'defaults the stdin stream to an empty string' do
    expect(invoke('$stdin.read')[1]).to eq ['""']
  end

  it 'can deal with methods that are invoked entirely on the next line' do
    expect(values_for("a = 1\n.even?\na")).to eq [['1'], ['false'], ['false']]
    expect(values_for("a = 1.\neven?\na")).to eq [['1'], ['false'], ['false']]
    expect(values_for("1\n.even?\n__END__")).to eq [['1'], ['false']]
  end

  it 'does not record leading comments' do
    expect(values_for("# -*- coding: utf-8 -*-\n'ç'\n__LINE__")).to eq [[], ['"ç"'], ['3']]
    expect(values_for("=begin\n1\n=end\n=begin\n=end\n__LINE__")).to eq [[], [], [],
                                                                     [], [],
                                                                     ['6']]
  end

  it 'times out if the timeout limit is exceeded' do
    expect { invoke "sleep 0.2", timeout: 0.1 }.to raise_error Timeout::Error
  end

  it 'records the exit status' do
    expect(invoke('raise "omg"').exitstatus).to eq 1
    expect(invoke('exit 123').exitstatus).to eq 123
    expect(invoke('at_exit { exit 121 }').exitstatus).to eq 121
  end

  it 'records lines that have comments on them' do
    expect(values_for('1+1 # comment uno
                      #comment dos
                      3#comment tres')).to eq [['2'], [], ['3']]
  end

  it "doesn't fuck up when there are lines with magic comments in the middle of the app" do
    expect(values_for '1+1
                       # encoding: wtf').to eq [['2']]
  end

  it "doesn't remove multiple leading comments" do
    expect(values_for "#!/usr/bin/env ruby\n"\
                      "# encoding: utf-8\n"\
                      "'ç'").to eq [[], [], ['"ç"']]
    expect(values_for "#!/usr/bin/env ruby\n"\
                      "1 # encoding: utf-8\n"\
                      "2").to eq [[], ['1'], ['2']]
  end

  it 'can record the middle of a chain of calls'  do
    expect(values_for("1 +\n2")).to eq [['1'], ['3']]
    expect(values_for("1\\\n+ 2")).to eq [['1'], ['3']]
    expect(values_for("[*1..5]
                        .select(&:even?)
                        .map { |n| n * 3 }")).to eq [['[1, 2, 3, 4, 5]'],
                                                     ['[2, 4]'],
                                                     ['[6, 12]']]
    expect(values_for("[*1..5]
                        .select(&:even?)
                        .map { |n| n * 2 }.
                        map  { |n| n / 2 }\\
                        .map { |n| n * 3 }")).to eq [['[1, 2, 3, 4, 5]'],
                                                        ['[2, 4]'],
                                                        ['[4, 8]'],
                                                        ['[2, 4]'],
                                                        ['[6, 12]']]
  end

  it 'can be limited to a specific number of captures' do
    expect(values_for "2.times do\n1\nend", number_of_captures: 1).to \
      eq [['2'],
          ['1', '...'],
          ['2']]
  end

  it 'can evaluate under a different ruby executable' do
    Dir.chdir proving_grounds_dir do
      File.write 'omg-ruby', "#!/usr/bin/env ruby
        $LOAD_PATH.unshift '#{File.expand_path '../../lib', __FILE__}'

        require 'seeing_is_believing/event_stream'
        sib = SeeingIsBelieving::EventStream::Publisher.new($stdout)
        sib.record_result(:inspect, 1, /omg/)
        sib.finish!
      "
      File.chmod 0755, 'omg-ruby'
      old_path = ENV['PATH']
      ENV['PATH'] = "#{proving_grounds_dir}:#{old_path}"
      begin
        expect(values_for("1", ruby_executable: 'omg-ruby')).to eq [["/omg/"]]
      ensure
        ENV['PATH'] = old_path
      end
    end
  end

  it 'does not record BEGIN and END', not_implemented: true do
    pending 'not implemented'
    expect { invoke <<-CODE }.to_not raise_error
      puts 1
      BEGIN {
        puts "begin code"
        some_var = 2
      }
      puts 3
      END {
        puts "end code"
        puts some_var
      }
      puts 4
    CODE
  end

  # For more info about this one
  # https://github.com/JoshCheek/seeing_is_believing/issues/24
  it 'does not blow up when executing commands that bypass stdout and talk directly to low-level stdout fd (e.g. C\'s system command from stdlib.h)' do
    expect(invoke(%q[system "ruby -e '$stdout.print ?a'"]).stdout).to eq "a"
    expect(invoke(%q[system "ruby -e '$stderr.print ?a'"]).stderr).to eq "a"
  end

  it 'does not blow up when inspect recurses infinitely' do
    result = invoke(%[def self.inspect
                        self
                      end
                      self], filename: 'blowsup.rb')
    expect(result).to have_exception
    expect(result.exception.class_name).to eq 'SystemStackError'
    expect(result.exception.backtrace.grep(/blowsup.rb/)).to_not be_empty # backtrace includes a line that we can show
    expect(result.exception.message).to match /recursive/i
  end

  it 'makes the SeeingIsBelieving::VERSION available to the program' do
    expect(values_for "SeeingIsBelieving::VERSION").to eq [[SeeingIsBelieving::VERSION.inspect]]
  end

  it 'does not change the number of lines in the file' do
    expect(values_for "File.read(__FILE__).lines.size").to eq [['1']]
  end

  context 'when given a debugger' do
    let(:stream)   { StringIO.new }
    let(:debugger) { SeeingIsBelieving::Debugger.new stream: stream }

    def call
      invoke "1", debugger: debugger
    end

    it 'prints the pre-evaluated program' do
      call
      expect(stream.string).to include "TRANSLATED PROGRAM:"
      expect(stream.string).to include "\nbegin;" # there is more, but we're just interested in showing that it wound up in the stream
    end

    it 'prints the result' do
      call
      expect(stream.string).to include "RESULT:"
      expect(stream.string).to include 'SIB::Result'
      expect(stream.string).to include '@results={'
    end
    # should ProgramRewriter have some debug options?
  end
end
