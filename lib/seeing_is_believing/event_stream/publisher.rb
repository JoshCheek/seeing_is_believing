require 'seeing_is_believing/event_stream/events'
class SeeingIsBelieving
  module EventStream
    require 'thread'
    # TODO: rename producer, don't forget about the one in the matrix
    class Publisher
      attr_accessor :exitstatus, :bug_in_sib, :max_line_captures, :num_lines

      def initialize(resultstream)
        self.exitstatus        = 0
        self.bug_in_sib        = false
        self.max_line_captures = Float::INFINITY
        self.num_lines         = 0
        self.recorded_results  = []
        self.queue             = Thread::Queue.new
        self.publisher_thread  = Thread.new do
          begin
            loop do
              to_publish = queue.shift
              if to_publish == "finish".freeze
                resultstream << "finish\n"
                break
              else
                resultstream << (to_publish << "\n")
              end
            end
          rescue IOError, Errno::EPIPE
            queue.clear # TODO: should probably keep emptying it until finish event
          end
        end
      end

      # TODO: delete?
      def bug_in_sib=(bool)
        @bug_in_sib = (bool ? true : false)
      end

      # for a consideration of many different ways of doing this, see 5633064
      def to_string_token(string)
        [Marshal.dump(string.to_s)].pack('m0')
      end

      # TODO: Use the type to inspect unless given a block
      StackErrors = [SystemStackError]
      StackErrors << Java::JavaLang::StackOverflowError if defined?(RUBY_PLATFORM) && RUBY_PLATFORM == 'java'
      def record_result(type, line_number, value)
        self.num_lines = line_number if num_lines < line_number
        counts = recorded_results[line_number] ||= Hash.new(0)
        count  = counts[type]
        recorded_results[line_number][type] = count.next
        if count < max_line_captures
          begin
            if block_given?
              inspected = yield(value).to_str
            else
              inspected = value.inspect.to_str
            end
          rescue *StackErrors
            # this is necessary because SystemStackError won't show the backtrace of the method we tried to call
            # which means there won't be anything showing the user where this came from
            # so we need to re-raise the error to get a backtrace that shows where we came from
            # otherwise it looks like the bug is in SiB and not the user's program, see https://github.com/JoshCheek/seeing_is_believing/issues/37
            raise SystemStackError, "Calling inspect blew the stack (is it recursive w/o a base case?)"
          rescue Exception
            inspected = "#<no inspect available>"
          end
          queue << "result #{line_number} #{type} #{to_string_token inspected}"
        elsif count == max_line_captures
          queue << "maxed_result #{line_number} #{type}"
        end
        value
      end

      def record_exception(line_number, exception)
        self.num_lines = line_number if num_lines < line_number
        queue << "exception"
        queue << "  line_number #{line_number}"
        queue << "  class_name  #{to_string_token exception.class.name}"
        queue << "  message     #{to_string_token exception.message}"
        exception.backtrace.each { |line|
          queue << "  backtrace   #{to_string_token line}"
        }
        queue << "end"
      end

      def record_stdout(stdout)
        queue << "stdout #{to_string_token stdout}"
      end

      def record_stderr(stderr)
        queue << "stderr #{to_string_token stderr}"
      end

      def finish!
        queue << "bug_in_sib #{bug_in_sib}"
        queue << "max_line_captures #{max_line_captures}"
        queue << "num_lines #{num_lines}"
        queue << "exitstatus #{exitstatus}"
        queue << "finish".freeze
        publisher_thread.join
      end

      private

      attr_accessor :resultstream, :queue, :publisher_thread, :recorded_results
    end
  end
end
