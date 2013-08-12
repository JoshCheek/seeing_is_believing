# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!


require 'yaml'
require 'stringio'
real_stdout = STDOUT
real_stderr = STDERR
STDOUT = $stdout = fake_stdout = StringIO.new
STDERR = $stderr = fake_stderr = StringIO.new

require 'seeing_is_believing/result'
$SiB = SeeingIsBelieving::Result.new

at_exit do
  $SiB.stdout = fake_stdout.string
  $SiB.stderr = fake_stderr.string

  $SiB.exitstatus ||= 0
  $SiB.exitstatus   = 1         if $!
  $SiB.exitstatus   = $!.status if $!.kind_of? SystemExit
  $SiB.bug_in_sib   = $! && ! $!.kind_of?(SystemExit)

  real_stdout.write YAML.dump $SiB
end
