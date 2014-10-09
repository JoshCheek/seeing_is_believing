# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!

# READ THIS IF YOU WANT TO USE YOUR OWN MATRIX FILE:
# https://github.com/JoshCheek/seeing_is_believing/issues/24
#
# (or if you want to understand why we do the pipe dance)

require_relative 'version'
require_relative 'event_stream/producer'

event_stream = STDOUT.dup  # duped Ruby object with the real file descriptor
$SiB = SeeingIsBelieving::EventStream::Producer.new(event_stream)

stdout = STDOUT # keep our own ref, b/c user could mess w/ constants and globals
read_stdout, write_stdout = IO.pipe
stdout.reopen(write_stdout)

stdout_bridge = Thread.new do
  while line = read_stdout.gets
    $SiB.record_stdout line
  end
  read_stdout.close
end


stderr = STDERR
read_stderr, write_stderr = IO.pipe
stderr.reopen(write_stderr)

stderr_bridge = Thread.new do
  while line = read_stderr.gets
    $SiB.record_stderr line
  end
  read_stderr.close
end

at_exit do
  # idk if this matters or not
  _, blackhole = IO.pipe # if it does, there should be something like File::NULL
  stdout.reopen(blackhole)
  stderr.reopen(blackhole)

  write_stdout.close unless write_stdout.closed?
  write_stderr.close unless write_stderr.closed?

  stdout_bridge.join
  stderr_bridge.join

  $SiB.record_exception nil, $! if $!
  $SiB.finish!
end
