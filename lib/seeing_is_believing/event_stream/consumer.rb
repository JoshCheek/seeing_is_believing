require 'seeing_is_believing/event_stream/events'
require 'seeing_is_believing/error'
require 'thread'

class SeeingIsBelieving
  module EventStream
    class Consumer
      NoMoreInput        = Class.new SeeingIsBelievingError
      WtfWhoClosedMyShit = Class.new SeeingIsBelievingError
      UnknownEvent       = Class.new SeeingIsBelievingError

      def initialize(streams)
        self.event_stream      = streams.fetch :events
        self.stdout_stream     = streams.fetch :stdout
        self.stderr_stream     = streams.fetch :stderr
        self.queue             = Thread::Queue.new

        self.stdout_thread = Thread.new do
          stdout_stream.each_line do |line|
            queue << Events::Stdout.new(line)
          end
          queue << :stdout_thread_finished
        end

        self.stderr_thread = Thread.new do
          stderr_stream.each_line do |line|
            queue << Events::Stderr.new(line)
          end
          queue << :stderr_thread_finished
        end

        self.event_thread = Thread.new do
          begin
            loop do
              break unless line = event_stream.gets
              event = event_for line
              queue << event
              break if Events::Finish === event
            end
          rescue IOError # TODO: does this still happen?
            queue << WtfWhoClosedMyShit.new("Our end of the pipe was closed!")
          rescue Exception
            queue << $!
          end
          queue << :event_thread_finished
        end
      end

      def call(n=1)
        return next_event if n == 1
        n.times.map { next_event }
      end

      def each
        return to_enum :each unless block_given?
        until finished?
          event = call
          yield event unless Events::Finish === event
        end
      rescue NoMoreInput
      end

      def finished?
        @finished
      end

      private

      attr_accessor :queue
      attr_accessor :event_thread, :stdout_thread, :stderr_thread
      attr_accessor :event_stream, :stdout_stream, :stderr_stream

      def next_event
        @finished_threads ||= [] # TODO: move me to initialize / attr_accessor
        event = queue.shift
        # puts "EVENT: #{event.inspect}"
        case event
        when Symbol
          @finished_threads << event
          if @finished_threads.size == 3
            @finished = true
            raise NoMoreInput
          else
            next_event
          end
        when SeeingIsBelievingError
          raise event
        else
          event
        end
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

      def event_for(original_line)
        line       = original_line.chomp
        event_name = extract_token(line).intern
        case event_name
        when :result
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          inspected   = extract_string(line)
          Events::LineResult.new(type, line_number, inspected)
        when :maxed_result
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          Events::UnrecordedResult.new(type, line_number)
        when :exception
          Events::Exception.new(-1, '', '', []).tap do |exception|
            loop do
              line = event_stream.gets.chomp
              case extract_token(line).intern
              when :line_number   then exception.line_number = extract_token(line).to_i
              when :class_name    then exception.class_name  = extract_string(line)
              when :message       then exception.message     = extract_string(line)
              when :backtrace     then exception.backtrace << extract_string(line)
              when :end           then break
              end
            end
          end
        # TODO: delete these, see if theres any others we can delete
        # TODO: delete them from the producer, too
        #
        # when :stdout
        #   Events::Stdout.new(extract_string line)
        # when :stderr
        #   Events::Stderr.new(extract_string line)
        when :max_line_captures
          token = extract_token(line)
          value = token =~ /infinity/i ? Float::INFINITY : token.to_i
          Events::MaxLineCaptures.new(value)
        when :exitstatus
          # TODO: Will this fuck it up if you run `exit true`?
          Events::Exitstatus.new(extract_token(line).to_i)
        when :finish
          Events::Finish.new
        when :num_lines
          Events::NumLines.new(extract_token(line).to_i)
        when :sib_version
          Events::SiBVersion.new(extract_string line)
        when :ruby_version
          Events::RubyVersion.new(extract_string line)
        when :filename
          Events::Filename.new(extract_string line)
        else
          raise UnknownEvent, original_line.inspect
        end
      end
    end
  end
end
