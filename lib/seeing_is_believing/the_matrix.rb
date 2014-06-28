# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!

# READ THIS IF YOU WANT TO USE YOUR OWN MATRIX FILE:
# https://github.com/JoshCheek/seeing_is_believing/issues/24
#
# (or if you want to understand why we do the pipe dance)


require 'yaml'
require 'seeing_is_believing/result'
$SiB = SeeingIsBelieving::Result.new

real_stdout = STDOUT.dup
real_stderr = STDERR.dup
read_from_fake_out, write_to_fake_out = IO.pipe
read_from_fake_err, write_to_fake_err = IO.pipe

STDOUT.reopen write_to_fake_out
STDERR.reopen write_to_fake_err

at_exit do
  STDOUT.reopen real_stdout
  STDERR.reopen real_stderr
  write_to_fake_out.close unless write_to_fake_out.closed?
  write_to_fake_err.close unless write_to_fake_err.closed?
  $SiB.stdout = read_from_fake_out.read
  $SiB.stderr = read_from_fake_err.read
  read_from_fake_out.close
  read_from_fake_err.close

  $SiB.exitstatus ||= 0
  $SiB.exitstatus   = 1         if $!
  $SiB.exitstatus   = $!.status if $!.kind_of? SystemExit
  $SiB.bug_in_sib   = $! && ! $!.kind_of?(SystemExit)

  real_stdout.write YAML.dump $SiB
end
