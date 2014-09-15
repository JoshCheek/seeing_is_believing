# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!

# READ THIS IF YOU WANT TO USE YOUR OWN MATRIX FILE:
# https://github.com/JoshCheek/seeing_is_believing/issues/24
#
# (or if you want to understand why we do the pipe dance)

require_relative 'event_stream'

stdout_real_obj = STDOUT      # the real Ruby object, fake file descriptor
stdout_real_fd  = STDOUT.dup  # duped Ruby object,    real file descriptor
read_from_mock_out, write_to_mock_out = IO.pipe
stdout_real_obj.reopen write_to_mock_out

stderr_real_obj = STDERR
stderr_real_fd  = STDERR.dup
read_from_mock_err, write_to_mock_err = IO.pipe
stderr_real_obj.reopen write_to_mock_err

$SiB = SeeingIsBelieving::EventStream::Publisher.new(stdout_real_fd)

at_exit do
  stdout_real_obj.reopen stdout_real_fd
  write_to_mock_out.close unless write_to_mock_out.closed?
  $SiB.record_stdout read_from_mock_out.read
  read_from_mock_out.close

  stderr_real_obj.reopen stderr_real_fd
  write_to_mock_err.close unless write_to_mock_err.closed?
  $SiB.record_stderr read_from_mock_err.read
  read_from_mock_err.close

  $SiB.exitstatus ||= 0
  $SiB.exitstatus   = 1         if $!
  $SiB.exitstatus   = $!.status if $!.kind_of? SystemExit
  $SiB.bug_in_sib   = $! && ! $!.kind_of?(SystemExit)

  $SiB.finish!
end
