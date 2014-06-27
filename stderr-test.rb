require 'stringio'

# looks like system and spawn both
# ultimately call rb_spawn_process in process.c
# which invokes C's "system" function
# from stdlib.h, which prints directly to its stdout
#
# setting $stdout and STDOUT don't seem to update its value

real_stdout = STDOUT
real_stderr = STDERR
STDOUT = $stdout = fake_stdout = StringIO.new
STDERR = $stderr = fake_stderr = StringIO.new

`echo backticks-stdout`
`echo backticks-stderr 2>&1`
%x(echo x-stdout)
%x(echo x-stderr 2>&1)
system "echo system-stdout"
system "echo system-stderr 2>&1"
spawn "echo spawn-stdout"
spawn "echo spawn-stderr 2>&1"

real_stdout.puts "STDOUT WAS: #{fake_stdout.string.inspect}"
real_stdout.puts "STDERR WAS: #{fake_stderr.string.inspect}"
