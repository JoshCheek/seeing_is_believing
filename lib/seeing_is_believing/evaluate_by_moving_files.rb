# Not sure what the best way to evaluate these is
# This approach will move the old file out of the way,
# write the program in its place, invoke it, and move it back.
#
# Another option is to replace __FILE__ macros ourselves
# and then write to a temp file but evaluate in the context
# of the expected directory. Some issues could arise with this,
# though: if you required the file again, it wouldn't already
# be in the loaded features (might be able to just add it)
# if you  did something like File.read(__FILE__) it would
# read the wrong file... of course, since we rewrite the file,
# its body will be incorrect, anyway.

require 'rbconfig'
require 'timeout'
require 'socket'
require 'seeing_is_believing/error'
require 'seeing_is_believing/result'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/hard_core_ensure'
require 'seeing_is_believing/event_stream/consumer'
require 'rubygems'
require "childprocess"

class SeeingIsBelieving
  class EvaluateByMovingFiles
    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :filename, :provided_input, :require_flags, :load_path_flags, :encoding, :timeout_seconds, :debugger, :event_handler, :max_line_captures

    def initialize(program, filename,  options={})
      options = options.dup
      self.program           = program
      self.filename          = filename
      self.encoding          = options.delete(:encoding)           || "u"
      self.timeout_seconds   = options.delete(:timeout_seconds)    || 0 # 0 is the new infinity
      self.provided_input    = options.delete(:provided_input)     || String.new
      self.event_handler     = options.delete(:event_handler)      || raise(ArgumentError, "must provide an :event_handler")
      self.load_path_flags   = (options.delete(:load_path_dirs)    || []).map { |dir| ['-I', dir] }.flatten
      self.require_flags     = (options.delete(:require_files)     || ['seeing_is_believing/the_matrix']).map { |filename| ['-r', filename] }.flatten
      self.max_line_captures = (options.delete(:max_line_captures) || Float::INFINITY) # (optimization: child stops producing results at this number, even though it might make more sense for the consumer to stop emitting them)
      options.any? && raise(ArgumentError, "Unknown options: #{options.inspect}")
    end

    def call
      HardCoreEnsure.call \
        code: -> {
          we_will_not_overwrite_existing_backup_file!
          backup_existing_file
          write_program_to_file
          evaluate_file
        },
        ensure: -> {
          set_back_to_initial_conditions
        }
    end

    def file_directory
      File.dirname filename
    end

    def backup_filename
      File.join file_directory, "seeing_is_believing_backup.#{File.basename filename}"
    end

    private

    def we_will_not_overwrite_existing_backup_file!
      raise TempFileAlreadyExists.new(filename, backup_filename) if File.exist? backup_filename
    end

    def backup_existing_file
      return unless File.exist? filename
      File.rename filename, backup_filename
      @was_backed_up = true
    end

    def set_back_to_initial_conditions
      if @was_backed_up
        File.rename(backup_filename, filename)
      else
        File.delete(filename)
      end
    end

    def write_program_to_file
      File.open(filename, 'w', external_encoding: "utf-8") { |f| f.write program.to_s }
    end

    # have to basically copy a bunch of Open3 code into here b/c keywords don't work right when the keys are not symbols
    # https://github.com/ruby/ruby/pull/808    my PR
    # https://bugs.ruby-lang.org/issues/10699  they opened an issue
    # https://bugs.ruby-lang.org/issues/10118  weird feature vs bug conversation
    def evaluate_file
      event_server = TCPServer.new(0) # dynamically allocates an available port

      # setup streams
      stdout,      child_stdout      = IO.pipe("utf-8")
      stderr,      child_stderr      = IO.pipe("utf-8")

      # setup environment variables
      env = ENV.to_hash.merge 'SIB_VARIABLES.MARSHAL.B64' =>
                                [Marshal.dump(
                                  event_stream_port: event_server.addr[1],
                                  max_line_captures: max_line_captures,
                                  num_lines:         program.lines.count,
                                  filename:          filename
                                )].pack('m0')

      child = ChildProcess.build(*popen_args)
      child.leader = true
      child.duplex = true
      child.environment.merge!(env)
      child.io.stdout = child_stdout
      child.io.stderr = child_stderr

      child.start

      # close child streams b/c they won't emit EOF
      # until both child and parent references are closed
      close_streams(child_stdout, child_stderr)
      child.io.stdin.binmode
      child.io.stdin.sync = true


      # Start receiving events from the child
      eventstream = event_server.accept

      # send stdin (char at a time b/c input could come from a stream)
      Thread.new do
        provided_input.each_char { |char| child.io.stdin.write char }
        child.io.stdin.close
      end

      # set up the event consumer
      consumer = EventStream::Consumer.new(events: eventstream, stdout: stdout, stderr: stderr)
      consumer_thread = Thread.new { consumer.each { |e| event_handler.call e } }

      # wait for completion
      if timeout_seconds == 0
        child.wait
      else
        child.poll_for_exit(timeout_seconds)
      end
      consumer.process_exitstatus(child.exit_code)
      consumer_thread.join
    rescue ChildProcess::TimeoutError
      consumer.process_timeout(timeout_seconds)
      child.stop
      consumer_thread.join
    ensure
      child.alive? && child.stop
      close_streams(stdout, stderr, eventstream, event_server)
    end

    def popen_args
      [RbConfig.ruby,
         '-W0',                                     # no warnings (b/c I hijack STDOUT/STDERR)
         *(encoding ? ["-K#{encoding}"] : []),      # allow the encoding to be set
         '-I', File.expand_path('../..', __FILE__), # add lib to the load path
         *load_path_flags,                          # users can inject dirs to be added to the load path
         *require_flags,                            # users can inject files to be required
         filename]
    end

    def close_streams(*streams)
      streams.each { |io| io.close unless io.closed? }
    end
  end
end
