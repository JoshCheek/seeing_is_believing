require 'seeing_is_believing/error'

class SeeingIsBelieving
  # At the CLI level, streaming will have to be opted into, b/c you'd need something on the other side that could display it
  module EventStream
    module Event
      LineResult       = Struct.new(:type, :line_number, :inspected)
      UnrecordedResult = Struct.new(:type, :line_number)
      Stdout           = Struct.new(:stdout)
      Stderr           = Struct.new(:stderr)
      BugInSiB         = Struct.new(:value)
      MaxLineCaptures  = Struct.new(:value)
      Exitstatus       = Struct.new(:value)
      Exception        = Struct.new(:line_number, :class_name, :message, :backtrace)
      Finish           = Class.new
    end

    class Consumer
      NoMoreInput = Class.new SeeingIsBelievingError

      def initialize(readstream)
        @readstream = readstream
      end

      def call(n=1)
        raise NoMoreInput if finished?
        if n == 1
          note_finish event_for @readstream.gets
        else
          n.times.map { note_finish event_for @readstream.gets }
        end
      end

      def finished?
        @finished
      end

      private

      def note_finish(event)
        @finished = true if event.class == Event::Finish
        event
      end

      def extract_token(line)
        event_name = line[/[^ ]+/]
        line.sub! /^\s*[^ ]+\s*/, ''
        event_name
      end

      # for a consideration of many different ways of doing this, see 5633064
      def extract_string(line)
        Marshal.load extract_token(line).unpack('m0').first
      end

      def tokenize(line)
        line.split(' ')
      end

      def event_for(line)
        line.chomp!
        event_name = extract_token(line).intern
        case event_name
        when :result
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          inspected   = extract_string(line)
          Event::LineResult.new(type, line_number, inspected)
        when :maxed_result
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          Event::UnrecordedResult.new(type, line_number)
        when :exception
          Event::Exception.new(-1, '', '', []).tap do |exception|
            loop do
              line = @readstream.gets.chomp
              case extract_token(line).intern
              when :line_number   then exception.line_number = extract_token(line).to_i
              when :class_name    then exception.class_name  = extract_string(line)
              when :message       then exception.message     = extract_string(line)
              when :backtrace     then exception.backtrace << extract_string(line)
              when :end           then break
              end
            end
          end
        when :stdout
          Event::Stdout.new(extract_string line)
        when :stderr
          Event::Stderr.new(extract_string line)
        when :bug_in_sib
          Event::BugInSiB.new(extract_token(line) == 'true')
        when :max_line_captures
          token = extract_token(line)
          value = token =~ /infinity/i ? Float::INFINITY : token.to_i
          Event::MaxLineCaptures.new(value)
        when :exitstatus
          # TODO: Will this fuck it up if you run `exit true`?
          Event::Exitstatus.new(extract_token(line).to_i)
        when :finish
          Event::Finish.new
        else
          raise "IDK what #{event_name.inspect} is!"
        end
      end
    end

    require 'thread'
    class Publisher
      attr_accessor :exitstatus, :bug_in_sib, :max_line_captures
      attr_accessor :recorded_results

      def initialize(resultstream)
        self.exitstatus        = 0
        self.bug_in_sib        = false
        self.max_line_captures = Float::INFINITY
        self.recorded_results  = []
        self.queue             = Thread::Queue.new
        self.publisher_thread  = Thread.new do
          loop do
            to_publish = queue.shift
            if to_publish == "finish".freeze
              resultstream << "finish\n"
              break
            else
              resultstream << (to_publish << "\n")
            end
          end
        end
      end

      # TODO: delete?
      def bug_in_sib=(bool)
        @bug_in_sib = !!bool
      end

      # for a consideration of many different ways of doing this, see 5633064
      def to_string_token(string)
        [Marshal.dump(string.to_s)].pack('m0')
      end

      # TODO: can record basic object and that shit
      # TODO: only records inspect once
      # TODO: Check whatever else result is currently doing
      def record_result(type, line_number, value)
        count = (recorded_results[line_number] ||= Hash.new(0))[type]
        recorded_results[line_number][type] = count.next
        if count < max_line_captures
          queue << "result #{line_number} #{type} #{to_string_token value.inspect}"
        elsif count == max_line_captures
          queue << "maxed_result #{line_number} #{type}"
        end
        value
      end

      def record_exception(line_number, exception)
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
        queue << "exitstatus #{exitstatus}"
        queue << "finish".freeze
      end

      private

      attr_accessor :resultstream, :queue, :publisher_thread
    end
  end
end
