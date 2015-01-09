# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!

# READ THIS IF YOU WANT TO USE YOUR OWN MATRIX FILE:
# https://github.com/JoshCheek/seeing_is_believing/issues/24
#
# (or if you want to understand why we do the pipe dance)

require_relative 'version'
require_relative 'event_stream/producer'

event_stream = IO.open(ARGV.shift.to_i, "w")
$SiB = SeeingIsBelieving::EventStream::Producer.new(event_stream)

stdout, stderr = STDOUT, STDERR
finish = lambda do
  $SiB.finish!
  event_stream.close
  stdout.flush
  stderr.flush
end

# TODO: Process.exec and Kernel.exec
# TODO: exec / exit! invoked incorrectly
real_exec      = method :exec
real_exit_bang = method :exit!
Kernel.module_eval do
  private

  define_method :exec do |*args, &block|
    # $SiB.record_exec(args)
    finish.call
    real_exec.call(*args, &block)
  end

  define_method :exit! do |status=false|
    $SiB.record_exitstatus status
    finish.call
    real_exit_bang.call(0)
  end
  module_function :exit!
end

at_exit do
  exitstatus = ($! ? $SiB.record_exception(nil, $!) : 0)
  $SiB.record_exitstatus exitstatus
  finish.call
  real_exit_bang.call(0) # clears exceptions so they don't print to stderr and change the processes actual exit status (we recorded what it should be)
end
