require 'seeing_is_believing/safe'
require 'seeing_is_believing/event_stream/events'
require 'thread' # <-- do we still need this?

using SeeingIsBelieving::Safe

class SeeingIsBelieving
  module EventStream
    class Producer

      # Guarding against hostile users (e.g. me) that do ridiculous things like blowing away these constants
      old_w, $-w = $-w, nil
      Object.constants.each do |name|
        const_set name, Object.const_get(name)
      end
      $-w = old_w

      ErrnoEPIPE = Errno::EPIPE # not actually tested, but we can see it is referenced below

      module NullQueue
        extend self
        Queue.instance_methods(false).each do |name|
          define_method(name) { |*| }
        end
      end

      attr_accessor :max_line_captures, :filename

      def initialize(resultstream)
        self.filename          = nil
        self.max_line_captures = Float::INFINITY
        self.recorded_results  = []
        self.queue             = Queue.new
        self.producer_thread   = build_producer_thread(resultstream)
      end

      attr_reader :version
      alias ver version
      def record_sib_version(sib_version)
        @version = sib_version
        queue << "sib_version #{to_string_token sib_version}"
      end

      def record_ruby_version(ruby_version)
        queue << "ruby_version #{to_string_token ruby_version}"
      end

      def record_max_line_captures(max_line_captures)
        self.max_line_captures = max_line_captures
        queue << "max_line_captures #{max_line_captures}"
      end

      def file_loaded
        queue << "file_loaded"
      end

      StackErrors = [SystemStackError]
      StackErrors << Java::JavaLang::StackOverflowError if defined?(RUBY_PLATFORM) && RUBY_PLATFORM == 'java'
      def record_result(type, line_number, value)
        counts = recorded_results[line_number] ||= Hash.new(0)
        count  = counts[type]
        recorded_results[line_number][type] = count.next
        if count < max_line_captures
          begin
            if block_given?
              inspected = yield(value)
            else
              inspected = value.inspect
            end
            unless String === inspected
              inspected = inspected.to_str
              raise unless String === inspected
            end
          rescue *StackErrors
            # this is necessary because SystemStackError won't show the backtrace of the method we tried to call
            # which means there won't be anything showing the user where this came from
            # so we need to re-raise the error to get a backtrace that shows where we came from
            # otherwise it looks like the bug is in SiB and not the user's program, see https://github.com/JoshCheek/seeing_is_believing/issues/37
            raise SystemStackError, "Calling inspect blew the stack (is it recursive w/o a base case?)"
          rescue Exception
            begin
              inspected = Kernel.instance_method(:inspect).bind(value).call
            rescue Exception
              inspected = "#<no inspect available>"
            end
          end
          queue << "result #{line_number.to_s} #{type.to_s} #{to_string_token inspected}"
        elsif count == max_line_captures
          queue << "maxed_result #{line_number.to_s} #{type.to_s}"
        end
        value
      end

      # records the exception, returns the exitstatus for that exception
      def record_exception(line_number, exception)
        return exception.status if SystemExit === exception # TODO === is not in the list
        unless line_number
          if filename
            begin line_number = exception.backtrace.grep(/#{filename.to_s}/).first[/:\d+/][1..-1].to_i
            rescue NoMethodError
            end
          end
        end
        line_number ||= -1
        queue << [
          "exception",
          line_number.to_s,
          to_string_token(exception.class.name),
          to_string_token(exception.message),
          exception.backtrace.size.to_s,
          *exception.backtrace.map { |line| to_string_token line }
        ].join(" ")
        1 # exit status
      end

      def record_filename(filename)
        self.filename = filename
        queue << "filename #{to_string_token filename}"
      end

      def record_exec(args)
        queue << "exec #{to_string_token args.inspect}"
      end

      def record_num_lines(num_lines)
        queue << "num_lines #{num_lines}"
      end

      def finish!
        queue << :break # note that consumer will continue reading until stream is closed, which is not the responsibility of the producer
        producer_thread.join
      end

      private

      attr_accessor :resultstream, :queue, :producer_thread, :recorded_results

      # for a consideration of many different ways of doing this, see 5633064
      def to_string_token(string)
        [Marshal.dump(string.to_s)].pack('m0')
      rescue TypeError => err
        raise unless err.message =~ /singleton can't be dumped/
        to_string_token string.to_s.dup
      end

      def build_producer_thread(resultstream)
        ::Thread.new {
          Thread.current.abort_on_exception = true
          begin
            resultstream.sync = true
            loop do
              to_publish = queue.shift
              break if :break == to_publish
              resultstream << (to_publish << "\n")
            end
          rescue IOError, Errno::EPIPE
            queue.clear
          ensure
            self.queue = NullQueue
            resultstream.flush rescue nil
          end
        }
      end

      def forking_occurred_and_you_are_the_child(resultstream)
        # clear the queue b/c we don't want to report the same lines 2x,
        # parent process can report them
        queue << :fork
        loop { break if queue.shift == :fork }

        # recreate the thread since forking in Ruby kills threads
        @producer_thread = build_producer_thread(resultstream)
      end

    end
  end
end
