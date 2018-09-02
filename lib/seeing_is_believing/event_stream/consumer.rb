# encoding: utf-8

require 'seeing_is_believing/event_stream/events'
require 'seeing_is_believing/error'
require 'thread'

# Polyfill String#scrub on Ruby 2.0.0
require 'seeing_is_believing/compatibility'
using SeeingIsBelieving::Compatibility

class SeeingIsBelieving
  module EventStream
    class Consumer
      # Contemplated doing FinishCriteria in binary, but the cost of doing it with an array
      # like this is negligible and it has the nice advantage that the elements in the array
      # are named # so if I ever look at it, I don't have to tranlsate a number to figure out
      # the names https://gist.github.com/JoshCheek/10deb07277b6c85efc7b5e65c007785d
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
        str.scrub('�')
      end

      def initialize(streams)
        @finished            = false
        self.finish_criteria = FinishCriteria.new
        self.queue           = Queue.new
        event_stream         = streams.fetch :events
        stdout_stream        = streams.fetch :stdout
        stderr_stream        = streams.fetch :stderr
        self.threads         = [
          Thread.new do
            begin
              stdout_stream.each_line { |line| queue << Events::Stdout.new(value: line) }
              queue << Events::StdoutClosed.new(side: :producer)
            rescue IOError
              queue << Events::StdoutClosed.new(side: :consumer)
            ensure
              queue << lambda { finish_criteria.stdout_thread_finished! }
            end
          end,

          Thread.new do
            begin
              stderr_stream.each_line { |line| queue << Events::Stderr.new(value: line) }
              queue << Events::StderrClosed.new(side: :producer)
            rescue IOError
              queue << Events::StderrClosed.new(side: :consumer)
            ensure
              queue << lambda { finish_criteria.stderr_thread_finished! }
            end
          end,

          Thread.new do
            begin
              event_stream.each_line { |line| queue << line }
              queue << Events::EventStreamClosed.new(side: :producer)
            rescue IOError
              queue << Events::EventStreamClosed.new(side: :consumer)
            ensure
              queue << lambda { finish_criteria.event_thread_finished! }
            end
          end,
        ]
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
        status ||= 1 # see #100
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

      def join
        threads.each(&:join)
      end

      private

      attr_accessor :queue, :finish_criteria, :threads

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

      def shift_token(line)
        event_name = line[/[^ ]+/]
        line.sub!(/^\s*[^ ]+\s*/, '')
        event_name
      end

      # For a consideration of many different ways of passing the message, see 5633064
      def shift_string(line)
        str = Marshal.load shift_token(line).unpack('m0').first
        Consumer.fix_encoding(str)
      end

      def event_for(original_line)
        line       = original_line.chomp
        event_name = shift_token(line).intern
        case event_name
        when :result
          line_number = shift_token(line).to_i
          type        = shift_token(line).intern
          inspected   = shift_string(line)
          Events::LineResult.new(type: type, line_number: line_number, inspected: inspected)
        when :maxed_result
          line_number = shift_token(line).to_i
          type        = shift_token(line).intern
          Events::ResultsTruncated.new(type: type, line_number: line_number)
        when :exception
          Events::Exception.new \
            line_number: shift_token(line).to_i,
            class_name:  shift_string(line),
            message:     shift_string(line),
            backtrace:   shift_token(line).to_i.times.map { shift_string line }
        when :max_line_captures
          token = shift_token(line)
          value = token =~ /infinity/i ? Float::INFINITY : token.to_i
          Events::MaxLineCaptures.new(value: value)
        when :num_lines
          Events::NumLines.new(value: shift_token(line).to_i)
        when :sib_version
          Events::SiBVersion.new(value: shift_string(line))
        when :ruby_version
          Events::RubyVersion.new(value: shift_string(line))
        when :filename
          Events::Filename.new(value: shift_string(line))
        when :exec
          Events::Exec.new(args: shift_string(line))
        else
          raise UnknownEvent, original_line.inspect
        end
      end
    end
  end
end
