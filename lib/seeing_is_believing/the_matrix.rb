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

real_exec      = method :exec
real_exit_bang = method :exit!
Kernel.module_eval do
  private

  define_method :exec do |*args, &block|
    $SiB.record_exec(args)
    finish.call
    real_exec.call(*args, &block)
  end

  define_method :exit! do |status=false|
    finish.call
    real_exit_bang.call(status)
  end
end

at_exit do
  exitstatus = ($! ? $SiB.record_exception(nil, $!) : 0)
  finish.call
  real_exit_bang.call(exitstatus) # clears exceptions so they don't print to stderr and change the processes actual exit status (we recorded what it should be)
end
