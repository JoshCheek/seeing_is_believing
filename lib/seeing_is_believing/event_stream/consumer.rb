# encoding: utf-8

require 'seeing_is_believing/event_stream/events'
require 'seeing_is_believing/error'
require 'thread'

class SeeingIsBelieving
  module EventStream
    class Consumer
      class FinishCriteria
        EventThreadFinished  = Module.new
        StdoutThreadFinished = Module.new
        StderrThreadFinished = Module.new
        ProcessExited        = Module.new

        def initialize
          @unmet_criteria = [
            EventThreadFinished,
            StdoutThreadFinished,
            StderrThreadFinished,
            ProcessExited,
          ]
        end

        # finish criteria are satisfied,
        # we can stop processing events
        def satisfied?
          @unmet_criteria.empty?
        end

        def event_thread_finished!
          @unmet_criteria.delete EventThreadFinished
        end

        def stdout_thread_finished!
          @unmet_criteria.delete StdoutThreadFinished
        end

        def stderr_thread_finished!
          @unmet_criteria.delete StderrThreadFinished
        end

        def received_exitstatus!
          @unmet_criteria.delete ProcessExited
        end

        def received_timeout!
          @unmet_criteria.delete ProcessExited
        end
      end

      # https://github.com/JoshCheek/seeing_is_believing/issues/46
      def self.fix_encoding(str)
        begin
          str.encode! Encoding::UTF_8
        rescue EncodingError
          str = str.force_encoding(Encoding::UTF_8)
        end
        return str.scrub('�') if str.respond_to? :scrub
        # basically reimplement scrub, b/c it's not implemented on 1.9.3
        str.each_char.inject("") do |new_str, char|
          if char.valid_encoding?
            new_str << char
          else
            new_str << '�'
          end
        end
      end

      def initialize(streams)
        @finished            = false
        self.finish_criteria = FinishCriteria.new
        self.queue           = Queue.new
        event_stream         = streams.fetch :events
        stdout_stream        = streams.fetch :stdout
        stderr_stream        = streams.fetch :stderr

        Thread.new do
          begin
            stdout_stream.each_line { |line| queue << Events::Stdout.new(value: line) }
            queue << Events::StdoutClosed.new(side: :producer)
          rescue IOError
            queue << Events::StdoutClosed.new(side: :consumer)
          ensure
            queue << lambda { finish_criteria.stdout_thread_finished! }
          end
        end

        Thread.new do
          begin
            stderr_stream.each_line { |line| queue << Events::Stderr.new(value: line) }
            queue << Events::StderrClosed.new(side: :producer)
          rescue IOError
            queue << Events::StderrClosed.new(side: :consumer)
          ensure
            queue << lambda { finish_criteria.stderr_thread_finished! }
          end
        end

        Thread.new do
          begin
            event_stream.each_line { |line| queue << line }
            queue << Events::EventStreamClosed.new(side: :producer)
          rescue IOError
            queue << Events::EventStreamClosed.new(side: :consumer)
          ensure
            queue << lambda { finish_criteria.event_thread_finished! }
          end
        end
      end

      def call(n=1)
        return next_event if n == 1
        Array.new(n) { next_event }
      end

      def each
        return to_enum :each unless block_given?
        yield call 1 until @finished
      end

      # NOTE: Note it's probably a bad plan to call these methods
      # from within the same thread as the consumer, because if it
      # blocks, who will remove items from the queue?
      def process_exitstatus(status)
        queue << lambda {
          queue << Events::Exitstatus.new(value: status)
          finish_criteria.received_exitstatus!
        }
      end
      def process_timeout(seconds)
        queue << lambda {
          queue << Events::Timeout.new(seconds: seconds)
          finish_criteria.received_timeout!
        }
      end


      private

      attr_accessor :queue, :finish_criteria

      def next_event
        raise NoMoreEvents if @finished
        case element = queue.shift
        when String
          event_for element
        when Proc
          element.call
          finish_criteria.satisfied? &&
            queue << Events::Finished.new
          next_event
        when Events::Finished
          @finished = true
          element
        when Event
          element
        else
          raise SeeingIsBelieving::UnknownEvent, "WAT IS THIS?: #{element.inspect}"
        end
      end

      def extract_token(line)
        event_name = line[/[^ ]+/]
        line.sub!(/^\s*[^ ]+\s*/, '')
        event_name
      end

      # For a consideration of many different ways of passing the message, see 5633064
      def extract_string(line)
        str = Marshal.load extract_token(line).unpack('m0').first
        Consumer.fix_encoding(str)
      end

      def event_for(original_line)
        line       = original_line.chomp
        event_name = extract_token(line).intern
        case event_name
        when :result
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          inspected   = extract_string(line)
          Events::LineResult.new(type: type, line_number: line_number, inspected: inspected)
        when :maxed_result
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          Events::ResultsTruncated.new(type: type, line_number: line_number)
        when :exception
          Events::Exception.new \
            line_number: extract_token(line).to_i,
            class_name:  extract_string(line),
            message:     extract_string(line),
            backtrace:   extract_token(line).to_i.times.map { extract_string line }
        when :max_line_captures
          token = extract_token(line)
          value = token =~ /infinity/i ? Float::INFINITY : token.to_i
          Events::MaxLineCaptures.new(value: value)
        when :num_lines
          Events::NumLines.new(value: extract_token(line).to_i)
        when :sib_version
          Events::SiBVersion.new(value: extract_string(line))
        when :ruby_version
          Events::RubyVersion.new(value: extract_string(line))
        when :filename
          Events::Filename.new(value: extract_string(line))
        when :exec
          Events::Exec.new(args: extract_string(line))
        else
          raise UnknownEvent, original_line.inspect
        end
      end
    end
  end
end
