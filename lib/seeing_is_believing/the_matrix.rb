require_relative 'version'
require_relative 'safe'
require_relative 'event_stream/producer'

sib_vars     = Marshal.load ENV["SIB_VARIABLES.MARSHAL.B64"].unpack('m0').first
event_stream = IO.open sib_vars.fetch(:event_stream_fd), "w"
$SiB = SeeingIsBelieving::EventStream::Producer.new(event_stream)
$SiB.record_ruby_version      RUBY_VERSION
$SiB.record_sib_version       SeeingIsBelieving::VERSION
$SiB.record_filename          sib_vars.fetch(:filename)
$SiB.record_num_lines         sib_vars.fetch(:num_lines)
$SiB.record_max_line_captures sib_vars.fetch(:max_line_captures)

STDOUT.sync = true
stdout = SeeingIsBelieving::Safe::Stream.new(STDOUT)
stderr = SeeingIsBelieving::Safe::Stream.new(STDERR)

finish = lambda do
  $SiB.finish!
  SeeingIsBelieving::Safe::Stream.new(event_stream).close
  stdout.flush
  stderr.flush
end

real_exec      = method :exec
real_exit_bang = method :exit!
Kernel.module_eval do
  private

  define_method :warn do |*args, &block|
    $stderr.puts *args
  end

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

# Do this Symbol thing b/c ruby C code calls it, so we can't wrap it
symbol_to_s = Symbol.instance_method(:to_s)
at_exit do
  Symbol.class_eval { define_method :to_s, symbol_to_s }

  exitstatus = ($! ? $SiB.record_exception(nil, $!) : 0)
  finish.call
  real_exit_bang.call(exitstatus) # clears exceptions so they don't print to stderr and change the processes actual exit status (we recorded what it should be)
end
