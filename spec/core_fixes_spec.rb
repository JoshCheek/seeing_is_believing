require 'seeing_is_believing/core_fixes'

# in MRI (in process.c)
#   Kernel#system is rb_f_system
#   Kernel#spawn  is rb_f_spawn
describe 'Kernel#system' do
  it 'prints to $stdout and $stderr instead of the original stdout and stderr' do
    original_stdout = $stdout
    original_stderr = $stderr
    begin
      $stdout = new_stdout = StringIO.new
      $stderr = new_stderr = StringIO.new
      system "ruby -e '$stdout.print %(a)'"
      system "ruby -e '$stderr.print %(b)'"
      new_stdout.string.should == 'a'
      new_stderr.string.should == 'b'
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end

  it 'returns true when the exit status is 0' do
    system("ruby -e 'exit 0'").should equal true
  end

  it 'returns false when the exit status is nonzero' do
    system("ruby -e 'exit 1'").should equal false
  end

  # TODO
  # args are parsed the same as for for <code>Kernel.spawn</code>.
  # call-seq:
  #    system([env,] command... [,options])    -> true, false or nil
  #   commandline                 : command line string which is passed to the standard shell
  #   cmdname, arg1, ...          : command name and one or more arguments (no shell)
  #   [cmdname, argv0], arg1, ... : command name, argv[0] and zero or more arguments (no shell)
  it 'returns nil if command execution fails' do
    system("x"*20).should equal nil
  end

  it 'uses ENV if no environment is provided'
  it 'can take an environment as the first arg'
  it 'sets $? to the last exit status'

  # system("echo *") # expands
  # system("echo", "*") # is a literal splat

  # The hash arguments, env and options, are same as
  # <code>exec</code> and <code>spawn</code>.
  # See <code>Kernel.spawn</code> for details.

  # system("echo *")
  # system("echo", "*")
end
