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

require 'open3'
require 'timeout'
require 'stringio'
require 'fileutils' # DELETE?
require 'seeing_is_believing/error'
require 'seeing_is_believing/result'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/hard_core_ensure'
require 'seeing_is_believing/event_stream/consumer'
require 'seeing_is_believing/event_stream/update_result'

class SeeingIsBelieving
  class EvaluateByMovingFiles

    # *sigh* have to do this b/c can't use Open3, b/c keywords don't work right when the keys are not symbols, and I'm passing a file descriptor
    # https://github.com/ruby/ruby/pull/808    my pr
    # https://bugs.ruby-lang.org/issues/10699  they opened an issue
    # https://bugs.ruby-lang.org/issues/10118  weird feature vs bug conversation
    module Spawn
      extend self
      def popen(*cmd)
        opts = {}
        opts = cmd.pop if cmd.last.kind_of? Hash

        in_r, in_w = IO.pipe
        opts[:in] = in_r
        in_w.sync = true

        out_r, out_w = IO.pipe
        opts[:out] = out_w

        err_r, err_w = IO.pipe
        opts[:err] = err_w

        pid       = spawn(*cmd, opts)
        wait_thr  = Process.detach(pid)

        in_r.close
        out_w.close
        err_w.close

        begin
          yield in_w, out_r, err_r, wait_thr
          in_w.close unless in_w.closed?
          wait_thr.value
        ensure
          [in_w, out_r, err_r].each { |io| io.close unless io.closed? }
          wait_thr.join
        end
      end
    end


    def self.call(*args)
      new(*args).call
    end

    attr_accessor :program, :filename, :input_stream, :require_flags, :load_path_flags, :encoding, :timeout, :ruby_executable, :debugger, :result

    def initialize(program, filename, options={})
      self.program         = program
      self.filename        = filename
      self.input_stream    = options.fetch :input_stream, StringIO.new('')
      self.require_flags   = options.fetch(:require, ['seeing_is_believing/the_matrix']).map { |filename| ['-r', filename] }.flatten
      self.load_path_flags = options.fetch(:load_path, []).map { |dir| ['-I', dir] }.flatten
      self.encoding        = options.fetch :encoding, nil
      self.timeout         = options[:timeout]
      self.ruby_executable = options.fetch :ruby_executable, 'ruby'
      self.debugger        = options.fetch :debugger, Debugger.new(stream: nil)
    end

    def call
      @result ||= HardCoreEnsure.call \
        code: -> {
          we_will_not_overwrite_existing_tempfile!
          move_file_to_tempfile
          write_program_to_file
          begin
            evaluate_file
            result
          rescue Exception => error
            error = wrap_error error unless error.kind_of? Timeout::Error
            raise error
          end
        },
        ensure: -> {
          set_back_to_initial_conditions
        }
    end

    def file_directory
      File.dirname filename
    end

    def temp_filename
      File.join file_directory, "seeing_is_believing_backup.#{File.basename filename}"
    end

    private

    attr_accessor :stdout, :stderr, :exitstatus

    def we_will_not_overwrite_existing_tempfile!
      raise TempFileAlreadyExists.new(filename, temp_filename) if File.exist? temp_filename
    end

    def move_file_to_tempfile
      return unless File.exist? filename
      FileUtils.mv filename, temp_filename
      @was_backed_up = true
    end

    def set_back_to_initial_conditions
      if @was_backed_up
        FileUtils.mv temp_filename, filename
      else
        FileUtils.rm filename
      end
    end

    def write_program_to_file
      File.open(filename, 'w') { |f| f.write program.to_s }
    end

    def evaluate_file
      # the event stream
      es_read, es_write = IO.pipe
      es_fd = es_write.to_i.to_s

      # invoke the process
      Spawn.popen ENV, *popen_args, es_fd, es_write => es_write do |process_stdin, process_stdout, process_stderr, thread|
        # child writes here, we close b/c won't get EOF until all fds are closed
        es_write.close

        # send stdin
        Thread.new {
          input_stream.each_char { |char| process_stdin.write char }
          process_stdin.close
        }

        # consume events
        self.result = Result.new # set on self b/c if an error is raised, we still want to keep what we recorded
        event_consumer = Thread.new do
          EventStream::Consumer
            .new(events: es_read, stdout: process_stdout, stderr: process_stderr)
            .each { |event| EventStream::UpdateResult.call result, event }
        end

        begin
          Timeout::timeout timeout do
            event_consumer.join
            # TODO: seems like these belong entirely on result, not as ivars of this class
            self.exitstatus = thread.value
            self.stderr     = result.stderr
          end
        rescue Timeout::Error
          Process.kill "TERM", thread.pid
          raise $!
        end
      end
    ensure
      es_read.close  unless es_read.closed?
      es_write.close unless es_write.closed?
    end

    def popen_args
      [ruby_executable,
         '-W0',                                     # no warnings (b/c I hijack STDOUT/STDERR)
         *(encoding ? ["-K#{encoding}"] : []),      # allow the encoding to be set
         '-I', File.expand_path('../..', __FILE__), # add lib to the load path
         *load_path_flags,                          # users can inject dirs to be added to the load path
         *require_flags,                            # users can inject files to be required
         filename]
    end

    def fail
      raise "Exitstatus: #{exitstatus.inspect},\nError: #{stderr.inspect}"
    end

    def wrap_error(error)
      debugger.context "Program could not be evaluated" do
        "Program:      #{program.inspect.chomp}\n\n"\
        "Stderr:       #{stderr.inspect.chomp}\n\n"\
        "Status:       #{exitstatus.inspect.chomp}\n\n"\
        "Result:       #{result.inspect.chomp}\n\n"\
        "Actual Error: #{error.inspect.chomp}\n"+
        error.backtrace.map { |sf| "              #{sf}\n" }.join("")
      end
      BugInSib.new error
    end
  end
end
