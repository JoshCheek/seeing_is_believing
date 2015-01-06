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

real_exec = method :exec
Kernel.module_eval do
  private
  define_method :exec do |*args, &block| # TODO: Add an event for exec?
    finish.call
    real_exec.call(*args, &block)
  end
end

at_exit do
  $SiB.record_exception nil, $! if $!
  finish.call
end
