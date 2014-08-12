# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!

# READ THIS IF YOU WANT TO USE YOUR OWN MATRIX FILE:
# https://github.com/JoshCheek/seeing_is_believing/issues/24
#
# (or if you want to understand why we do the pipe dance)


require 'json'
require 'seeing_is_believing/result'
$SiB = SeeingIsBelieving::Result.new

stdout_real_obj = STDOUT      # the real Ruby object, but its FD is going to keep getting reopened
stderr_real_obj = STDERR
stdout_real_fd  = STDOUT.dup  # duped Ruby object, but with the real file descriptor
stderr_real_fd  = STDERR.dup

read_from_mock_out, write_to_mock_out = IO.pipe
read_from_mock_err, write_to_mock_err = IO.pipe

stdout_real_obj.reopen write_to_mock_out
stderr_real_obj.reopen write_to_mock_err

at_exit do
  stdout_real_obj.reopen stdout_real_fd
  stderr_real_obj.reopen stderr_real_fd
  write_to_mock_out.close unless write_to_mock_out.closed?
  write_to_mock_err.close unless write_to_mock_err.closed?
  $SiB.stdout = read_from_mock_out.read
  $SiB.stderr = read_from_mock_err.read
  read_from_mock_out.close
  read_from_mock_err.close

  $SiB.exitstatus ||= 0
  $SiB.exitstatus   = 1         if $!
  $SiB.exitstatus   = $!.status if $!.kind_of? SystemExit
  $SiB.bug_in_sib   = $! && ! $!.kind_of?(SystemExit)

  stdout_real_fd.write JSON.dump $SiB.to_primitive
end
