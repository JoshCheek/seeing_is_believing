# -*- coding: utf-8 -*-


require 'spec_helper'
require 'stringio'
require 'seeing_is_believing'
require 'childprocess'

RSpec.describe SeeingIsBelieving do
  def method_result(name)
    @result = def __some_method__; end
    if :__some_method__ == @result
      name.inspect
    elsif nil == @result
      nil.inspect
    else
      raise "huh? #{@result.inspect}"
    end
  end

  def invoke(input, options={})
    if options[:debug]
      options.delete :debug
      options[:debugger] = SeeingIsBelieving::Debugger.new(stream: $stderr, colour: true)
    end
    described_class.new(input, options).call.result
  end

  def values_for(input, options={})
    invoke(input, options).to_a
  end

  root_path       = File.expand_path("../..", __FILE__)
  proving_grounds = File.expand_path('proving_grounds', root_path)
  before(:all) { Dir.mkdir proving_grounds unless Dir.exist? proving_grounds }
  around { |spec| Dir.chdir proving_grounds, &spec }

  let(:proving_grounds_dir) { File.expand_path '../../proving_grounds', __FILE__ }

  it 'takes a string and returns a result of the line numbers (counting from 1) and each inspected result from that line' do
    input  = "10+10\n'2'+'2'"
    expect(invoke(input)[1]).to eq ["20"]
    expect(invoke(input)[2]).to eq ['"22"']
  end

  it 'blows up if given unknown options' do
    expect { invoke '', not_an_option: 123 }.to raise_error KeyError, /not_an_option/
  end

  it 'only invokes inspect once' do
    input = "class Array; def inspect; 'INSPECTED'\nend\nend\n[]"
    expect(invoke(input)[1]).to eq ['"INSPECTED"']
  end

  it 'makes the SiB version info available' do
    expect(invoke('$SiB.ver')[1][0]).to eq SeeingIsBelieving::VERSION.inspect
  end

  it 'records various useful information on the result' do
    result = invoke '', max_line_captures: 10, filename: 'abc.rb'
    expect(result.sib_version).to eq SeeingIsBelieving::VERSION
    expect(result.ruby_version).to eq RUBY_VERSION
    expect(result.max_line_captures).to eq 10
    expect(result.num_lines).to eq 1
    expect(result.filename).to eq 'abc.rb'
  end

  it 'makes the Ruby version info available' do
    expect(invoke('').ruby_version).to eq RUBY_VERSION
  end

  it 'allows users to pass in their own rewrite_code' do
    wrapper = lambda { |program|
      SeeingIsBelieving::WrapExpressions.call program,
        before_each: -> * { '(' },
        after_each:  -> line_number { ").tap { $SiB.record_result(:inspect, #{line_number}, 'zomg') }" }
    }
    expect(invoke(':body', rewrite_code: wrapper)[1]).to eq ['"zomg"']
  end

  it 'remembers context of previous lines' do
    expect(values_for("a=12\na*2")).to eq [['12'], ['24']]
  end

  it 'can be invoked multiple times, returning the same result' do
    believer = described_class.new("$xyz||=1\n$xyz+=1")
    expect(believer.call).to eq believer.call
    expect(believer.call.result.to_a).to eq [['1'], ['2']]
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
    expect(values_for("<<HEREDOC\n\n1\nHEREDOC")).to eq  [[%Q'"\\n1\\n"'], [], [], []] # newlines escaped b/c lib inspects them
    expect(values_for("<<-HEREDOC\n\n1\nHEREDOC")).to eq [[%Q'"\\n1\\n"'], [], [], []]
  end

  it 'records the targets of chained methods' do
    expect(values_for("[*1..5]\n.map { |n| n * 2 }\n.take(2)\n.size")).to eq\
      [["[1, 2, 3, 4, 5]"], ["[2, 4, 6, 8, 10]"], ["[2, 4]"], ["2"]]
  end

  it 'does not add additional vars' do
    expect(values_for 'local_variables').to eq [["[]"]]
  end

  it "records heredocs" do
    expect(values_for("<<A\n1\nA")).to  eq [[%'"1\\n"'], [], []]
    expect(values_for("<<-A\n1\nA")).to eq [[%'"1\\n"'], [], []]
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

  context 'exceptions in exit blocks' do
    # I'm punting on this because there is just no good way to stop that from happening without changing actual behaviour
    # see https://github.com/JoshCheek/seeing_is_believing/issues/24
    it 'does not include information about the_matrix in the exception backtraces' do
      result1 = invoke("raise Exception, 'something'")
      result2 = invoke("at_exit { raise Exception, 'something' }")
      result1.exception.backtrace.each { |line| expect(line).to_not match /the_matrix/ }
      result2.exception.backtrace.each { |line| expect(line).to_not match /the_matrix/ }
    end

    it 'can print in at_exit hooks' do
      result = invoke("at_exit { $stderr.print 'err output'; $stdout.print 'out output' }")
      expect(result.stderr).to eq 'err output'
      expect(result.stdout).to eq 'out output'
    end

    it 'can see previous hooks exceptions' do
      result = invoke("at_exit { puts $!.message.reverse}; at_exit { raise 'reverse this' }")
      expect(result.stdout).to eq "siht esrever\n"
    end
  end

  it 'supports catch/throw' do
    values = values_for("catch :zomg do\n"\
                        "  1\n"\
                        "  throw :zomg\n"\
                        "  2\n"\
                        "end")
    expect(values).to eq [[], ['1'], [], [], ['nil']]

    result = invoke("throw :zomg")
    expect(result.exception.message).to match /:zomg/
  end

  it 'does not fuck up the __ENCODING__ macro' do
    expect(values_for("# encoding: utf-8
                      __ENCODING__")).to eq [[], ["#<Encoding:UTF-8>"]]
    expect(values_for("# encoding: ascii-8bit
                      __ENCODING__")).to eq [[], ["#<Encoding:ASCII-8BIT>"]]
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
    ).to eq [['1'], ['2'], [], [], ['5'], [method_result(:meth)], ['5'], [], [], ['10']]
  end

  it 'records return statements' do
    expect(values_for("def meth \n return 1          \n end \n meth")).to eq [[], ['1'], [method_result(:meth)], ['1']]
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
    expect(values_for(<<-DOC)).to eq [[], ['0'], ['0...3'], ['1', '2', '3', '4'], ['false', 'true', 'false', 'false'], ['0...3'], [method_result(:meth)], ['0...3']]
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
    expect(values_for(<<-DOC)).to eq [[], [], [], [method_result(:meth)], ['nil']]
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
    expect(values_for("1+1\nDATA.read\n__END__\n....")).to eq [['2'], ['"....\n"'], [], []] # <-- should this actually write a newline on the end?
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
    expect(values_for("1\n.even?\n__END__")).to eq [['1'], ['false'], []]
  end

  it 'does not record leading comments' do
    expect(values_for("# -*- coding: utf-8 -*-\n'ç'\n__LINE__")).to eq [[], ['"ç"'], ['3']]
    expect(values_for("=begin\n1\n=end\n=begin\n=end\n__LINE__")).to eq [[], [], [],
                                                                     [], [],
                                                                     ['6']]
  end

  it 'records the timeouts on the result' do
    result = invoke "1"
    expect(result).to_not be_timeout
    expect(result.timeout_seconds).to eq nil

    result = invoke "sleep 0.2", timeout_seconds: 0.1
    expect(result).to be_timeout
    expect(result.timeout_seconds).to eq 0.1
  end

  it 'records the exit status' do
    expect(invoke(""                    ).exitstatus).to eq 0   # happy path: no exceptions
    expect(invoke('raise "omg"'         ).exitstatus).to eq 1   # exceptions: status is 1
    expect(invoke('exit'                ).exitstatus).to eq 0   # call exit, but with no args
    expect(invoke('exit 0'              ).exitstatus).to eq 0   # set numeric status with exit
    expect(invoke('exit 123'            ).exitstatus).to eq 123
    expect(invoke('exit true'           ).exitstatus).to eq 0   # set boolean status with exit
    expect(invoke('exit false'          ).exitstatus).to eq 1
    expect(invoke('at_exit { exit 121 }').exitstatus).to eq 121 # when status is set in an at_exit hook

    # setting status with exit!
    # since we might be overriding this (a questionable decision) we make sure it behaves as expected (no at_exit hooks are called)
    result = invoke 'at_exit { puts "omg" }; exit!'
    expect([result.exitstatus, result.stdout, result.stderr]).to eq [1, '', '']

    result = invoke 'at_exit { puts "omg" }; exit! 100'
    expect([result.exitstatus, result.stdout]).to eq [100, '']

    result = invoke 'at_exit { puts "omg" }; Kernel.exit! 101'
    expect([result.exitstatus, result.stdout]).to eq [101, '']

    result = invoke 'at_exit { puts "omg" }; Kernel.exit! 102'
    expect([result.exitstatus, result.stdout]).to eq [102, '']
  end


  it 'records lines that have comments on them' do
    expect(values_for('1+1 # comment uno
                      #comment dos
                      3#comment tres')).to eq [['2'], [], ['3']]
  end

  it "doesn't fuck up when there are lines with magic comments in the middle of the app" do
    expect(values_for '1+1
                       # encoding: wtf').to eq [['2'], []]
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

  it 'can be limited to a specific number of captures per line' do
    expect(values_for "2.times do\n1\nend", max_line_captures: 1).to \
      eq [['2'],
          ['1', '...'],
          ['2']]
  end

  describe 'BEGIN and END' do
    it 'doesn\'t fuck up when the BEGIN block exits / raises' do
      expect(invoke("BEGIN { exit 100 }").exitstatus).to eq 100
      expect(invoke("BEGIN { exit! 100 }").exitstatus).to eq 100
      expect(invoke("BEGIN { raise Exception, 'wat'}").exception.message).to eq 'wat'
    end

    it 'Executes in the appropriate order' do
      expect(invoke(<<-CODE).stdout).to eq "1\n2\n3\n4\n5\n6\n7\n8\n9\n"
        p 3
        END   { p 9 }
        p 4
        BEGIN { p 1 }
        p 5
        END   { p 8 }
        p 6
        BEGIN { p 2 }
        p 7
      CODE
    end

    it 'Maintains correct line numbers' do
      expected_values = [
        ['1'],
        [],
        ['3'],
        [],
        ['5'],
        [],
        ['7'],
        [],
        ['9'],
      ]
      expect(values_for <<-CODE).to eq expected_values
        __LINE__
        BEGIN {
          __LINE__
        }
        __LINE__
        END {
          __LINE__
        }
        __LINE__
      CODE
    end
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
    expect(values_for "File.read(__FILE__).lines.count").to eq [['1']]
  end

  it 'records instances of BasicObject' do
    expect(values_for 'o = BasicObject.new; def o.inspect; "some obj"; end; o').to eq [['some obj']]
  end

  # https://github.com/JoshCheek/seeing_is_believing/issues/53
  it 'respects timeout, even when children do semi-ridiculous things, it cleans up children rather than orphaning them' do
    pre    = Time.now
    result = invoke <<-CHILD, timeout_seconds: 0.1
      read, _ = IO.pipe

      spawn 'ruby', '-e', <<-GRANDCHILD, in: read
        puts Process.pid  # print grandchild id
        $stdin.read       # block grandchild
      GRANDCHILD

      puts Process.pid    # print child pid
      read.read           # block child
    CHILD
    post   = Time.now
    expect(result.timeout?).to eq true
    expect(result.timeout_seconds).to eq 0.1
    expect(post - pre).to be > 0.1
    child_id, grandchild_id = result.stdout.lines.map(&:to_i).each { |id| expect(id).to be > 0 }
    expect { Process.wait child_id      } .to raise_error /no.*processes/i
    expect { Process.wait grandchild_id } .to raise_error /no.*processes/i
  end


  # see https://github.com/JoshCheek/seeing_is_believing/pull/92
  # and https://github.com/JoshCheek/seeing_is_believing/pull/94
  it 'kills the child and all of its children when the main SiB process gets killed, even if they\'re nonsensing it up' do
    # start SiB, it will make a child, use --stream so we can
    # access individual events as they are emitted (to get the pids)
    bin_path = File.realpath '../bin/seeing_is_believing', __dir__
    sib = ChildProcess.build bin_path, '--stream', '-e', <<-RUBY
      # the child makes a grandchild that ignores interrupts and sleeps
      spawn 'ruby', '-e', <<-GRANDCHILD
        trap 'INT', 'IGNORE'
        sleep
      GRANDCHILD

      # the child ignores interrupts and sleeps
      trap 'INT', 'IGNORE'
      Process.pid
      sleep
    RUBY

    # Hook up the io and start the child process
    read, write   = IO.pipe
    sib.io.stdout = write
    sib.io.stderr = write
    sib.duplex    = true # otherwise it takes the real process's stdin, which will mess w/ pry
    sib.start
    write.close

    # Get the child and grandchild ids. If we read too far, we lock up the test
    pids = []
    until pids.length == 2
      event, data = JSON.parse read.gets
      next unless event == 'line_result'
      next unless data.fetch('inspected') =~ /\A\d+\z/
      pids << data.fetch('inspected').to_i
    end

    # Interrupt SiB, it interrupts child and grandchild
    expect(sib).to be_alive
    Process.kill 'INT', sib.pid

    # wait for it to finish cleaning up so we don't check pids before it gets around to killing them
    sib.wait

    # Apparently we can check if processes exist by sending them signal 0
    # http://stackoverflow.com/questions/9152979/check-if-process-exists-given-its-pid
    # ESRCH = "no such process", what we expect if SiB cleaned them up
    # if they do exist, they will return `1` (in my experiments)
    pids.each do |pid|
      expect { Process.kill 0, pid }.to raise_error Errno::ESRCH
    end
  end


  context 'when given a debugger' do
    let(:stream)   { StringIO.new }
    let(:debugger) { SeeingIsBelieving::Debugger.new stream: stream }

    def call
      result = invoke "1", debugger: debugger
      expect(result[1]).to eq ["1"]
      result
    end

    it 'prints the pre-evaluated program' do
      call
      expect(stream.string).to include "REWRITTEN PROGRAM:"
      expect(stream.string).to include "$SiB.record_result" # there is more, but we're just interested in showing that it wound up in the stream
    end

    it 'records eventstream information' do
      call
      expect(stream.string).to include "EVENTS"
    end
  end

  describe 'fork', needs_fork: true do
    it 'records results from both parent and child, without double reporting items that may have been left in the queue at the time of forking' do
      n = 100
      result = invoke <<-RUBY
        n  = #{n}
        as = '0' * n; 0
        bs = '1' * n; 1

        $$
        if fork
          $$
          print as
        else
          $$
          print bs
        end
        $$
      RUBY

      expect(result[1]).to eq [n.to_s]
      expect(result[2]).to eq ['0']
      expect(result[3]).to eq ['1']
      expect(result[4]).to eq []
      ppid = result[5][0]
      pid, null = result[6].sort
      expect(null).to eq 'nil'

      expect(result[ 7]).to eq [ppid]
      expect(result[10]).to eq [pid]
      expect(result[13].sort).to eq [pid, ppid].sort

      zeros, ones = result.stdout.split(/01|10/).sort
      expect(zeros).to eq ("0"*(n-1)) # spent one on the split
      expect(ones).to  eq ("1"*(n-1))
    end

    it 'works for Kernel#fork, Kernel.fork, Process.fork', needs_fork: true do
      result = invoke <<-RUBY
        $$
        if fork
          $$
        elsif Kernel.fork
          $$
        elsif Process.fork
          $$
        else
          $$
        end
        $$
      RUBY

      pid_main = result[1][0]

      pid_private, null = result[2].sort
      expect(result[3]).to eq [pid_main]
      expect(null).to eq 'nil'

      pid_kernel,  null = result[4].sort
      expect(result[5]).to eq [pid_private]
      expect(null).to eq 'nil'

      pid_process, null = result[6].sort
      expect(result[7]).to eq [pid_kernel]
      expect(null).to eq 'nil'

      expect(result[9]).to eq [pid_process]
      expect(result[11].sort).to eq [pid_main, pid_private, pid_kernel, pid_process].sort
    end
  end

  describe 'exec' do
    it 'passes stdin, stdout, stderr, and actually does exec the process' do
      result = invoke \
        "1+1\n"\
        "$stdout.puts *1..1000\n"\
        "$stderr.puts *1..1000\n"\
        "exec %(ruby -e '$stdout.puts %{from stdin: } + gets.inspect
                         $stdout.puts %[out from exec]
                         $stderr.puts %[err from exec]')\n"\
        "$stdout.puts 'this will never be executed'",
         stdin: "the-stdin-dataz"
      expect(result[1]).to eq ['2']
      nums = (1..1000).map { |n| "#{n}\n" }.join('')
      expect(result.stdout).to eq "#{nums}from stdin: \"the-stdin-dataz\"\nout from exec\n"
      expect(result.stderr).to eq "#{nums}err from exec\n"
    end

    it 'works for Kernel#exec, Kernel.exec, Process.exec' do
      expect(invoke('exec "ruby", "-e", "puts %(hello)"').stdout).to eq "hello\n"
      expect(invoke('Kernel.exec "ruby", "-e", "puts %(hello)"').stdout).to eq "hello\n"
      expect(invoke('Process.exec "ruby", "-e", "puts %(hello)"').stdout).to eq "hello\n"
    end

    it 'gets the exit status off of the child process' do
      expect(invoke('exec "ruby", "-e", "exit 5"').exitstatus).to eq 5
    end

    it 'emits otuput on expicit invocations to warn' do
      expect(invoke('warn "hello"').stderr).to eq "hello\n"
    end
  end

  # Looked through the implementation of event_stream/producer to find a list of core behaviour it depends on
  # this is a list of things to check that it can work without.
  # based on this issue: https://github.com/JoshCheek/seeing_is_believing/issues/55
  describe 'it works even in hostile environments' do
    specify 'when IO does not have sync=, <<, flush, puts, close' do
      expect(invoke('class IO
                       undef sync
                       undef <<
                       undef flush
                       undef puts
                       undef close
                     end').stderr).to eq ''
    end

    specify 'when Queue does not have <<, shift, and clear' do
      expect(invoke('class Queue
                       undef <<
                       undef shift
                       undef clear
                     end').stderr).to eq ''
    end

    specify 'when Symbol does not have ==, to_s, inspect' do
      expect(invoke('class Symbol
                       undef ==
                       undef to_s
                       undef inspect
                     end').stderr).to eq ''
    end

    specify 'when String does not have ==, to_s, inspect, to_i' do
      expect(invoke('class String
                       undef ==
                       undef to_s
                       undef to_str
                       undef inspect
                       undef to_i
                     end').stderr).to eq ''
    end

    specify 'when Fixnum does not have <, <<, next, ==, inspect, to_s' do
      if defined? Fixnum
        result = invoke('class Fixnum
                           undef <
                           undef <<
                           undef ==
                           def next
                             "redefining instead of undefing b/c it comes from Integer"
                           end
                           undef to_s
                           undef inspect
                         end
                         "a"')
        expect(result.stderr).to eq ''
        expect(result.exitstatus).to eq 0
        expect(result.to_a.last).to eq ['"a"']
      end
    end

    specify 'when Integer does not have <, <<, next, ==, inspect, to_s' do
      result = invoke('class Integer
                         undef <
                         undef << if instance_methods.include? :<<   # ruby 2.4+
                         undef ==
                         undef next
                         undef to_s
                         undef inspect
                       end
                       "a"')
      expect(result.stderr).to eq ''
      expect(result.exitstatus).to eq 0
      expect(result.to_a.last).to eq ['"a"']
    end

    specify 'when Hash does not have [], []=, fetch' do
      RUBY_VERSION == '2.0.0' and
        skip '2.0.0 implements all the thread stuff in Ruby, with no obvious way to override its attempt to call removed methods'
      expect(invoke('class Hash
                       undef []
                       undef []=
                       undef fetch
                     end').stderr).to eq ''
    end

    specify 'when Array does not have pack, <<, to_ary, grep, first, [], []=, each, map' do
      expect(invoke('class Array
                       undef pack
                       undef <<
                       undef to_ary
                       undef grep
                       undef first
                       undef []
                       undef []=
                       undef each
                       undef map
                       undef join
                       undef size
                     end').stderr).to eq ''
    end

    specify 'when Marshal does not have dump, load' do
      expect(invoke('class << Marshal
                       undef dump
                       undef load
                     end').stderr).to eq ''
    end

    # defined? is a macro, not a method, otherwise I'd test that here
    specify 'when Kernel does not have kind_of?' do
      expect(invoke('module Kernel
                       undef kind_of?
                     end
                     1').to_a).to eq [[], [], ['nil'], ['1']]
    end

    specify 'when Enumerable does not have map' do
      expect(invoke('module Enumerable
                       undef map
                     end
                    ').stderr).to eq ''
    end

    specify 'when SystemExit does not have status' do
      # its fine to blow up if they undefine it and then they call exit,
      # that's probably the expected behaviour
      # But our code should be as resilient as possible,
      # so shouldn't blow up b/c some feature happened to call exit
      expect(invoke('class SystemExit
                       undef status
                     end
                    ').stderr).to eq ''
    end

    specify 'when Exception does not have message, class (can\'t get backtrace to work)' do
      result = invoke('begin
                         raise "hello"
                       ensure
                         class Exception
                           undef message
                           undef backtrace
                           def class; "totally the wrong thing" end
                         end
                       end
                      ')
      expect(result.exception.message).to eq 'hello'
      expect(result.exception.backtrace.length).to eq 1
      expect(result.exception.backtrace[0]).to match /program\.rb:\d/
      expect(result.exception.class_name).to eq 'RuntimeError'
    end

    specify 'when Thread does not have .new, .current, #join, #abort_on_exception', needs_fork: true do
      expect(invoke('class << Thread
                       undef new
                       undef current if "2.0.0" != RUBY_VERSION && "1.9.3" != RUBY_VERSION
                     end
                     class Thread
                       undef join
                       undef abort_on_exception
                     end
                     fork
                     1
                    ').stderr).to eq ''
    end

    specify 'when Class does not have new, allocate, singleton_class, class_eval' do
      expect(invoke('class Class
                       undef new
                       undef allocate
                       undef singleton_class
                       undef class_eval
                     end
                    ').stderr).to eq ''
    end

    specify 'when Class#new is overridden' do
      result = invoke('class Class
                         def new(arg)
                           arg
                         end
                       end
                       class A
                       end
                       A.new 123')
      expect(result.exception).to eq nil
      expect(result[3]).to eq ["123"]
    end

    specify 'when BasicObject does not have initialize' do
      expect(invoke('class BasicObject
                       undef initialize
                     end
                    ').stderr).to eq ''
    end

    specify 'when Module does not have define_method, instance_method' do
      expect(invoke('class Module
                       undef define_method
                       undef instance_method
                     end
                    ').stderr).to eq ''
    end

    specify 'when UnboundMethod does not have bind' do
      expect(invoke('class UnboundMethod
                       undef bind
                     end
                    ').stderr).to eq ''
    end

    specify 'when Method does not have call' do
      expect(invoke('class Method
                       undef call
                     end
                    ').stderr).to eq ''
    end

    specify 'when Proc does not have call, to_proc' do
      expect(invoke('class Proc
                       undef call
                       undef to_proc
                     end
                    ').stderr).to eq ''
    end

    # Apparently it doesn't have a to_proc method, they must check to see if it's nil in the code that implements &
    specify 'when nil does not have to_s' do
      expect(invoke('class NilClass
                       undef to_s
                     end
                    ').stderr).to eq ''
    end
  end
end
