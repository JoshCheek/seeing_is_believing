# encoding: utf-8

require 'seeing_is_believing/event_stream/events'
require 'seeing_is_believing/error'
require 'thread'

class SeeingIsBelieving
  module EventStream
    class Consumer
      class FinishCriteria
        CRITERIA = [
          :event_thread_finished!,
          :stdout_thread_finished!,
          :stderr_thread_finished!,
          :process_exited!,
        ].freeze.each do |name|
          define_method name do
            @unmet_criteria.delete name
            @satisfied = @unmet_criteria.empty?
          end
        end
        def initialize
          @satisfied      = false
          @unmet_criteria = CRITERIA.dup
        end
        def satisfied?
          @satisfied
        end
      end

      # https://github.com/JoshCheek/seeing_is_believing/issues/46
      def self.fix_encoding(str)
        str.encode! Encoding::UTF_8
      rescue EncodingError
        str = str.force_encoding(Encoding::UTF_8)
        return str.scrub('�') if str.respond_to? :scrub # b/c it's not implemented on 1.9.3
        str.each_char.inject("") do |new_str, char|
          if char.valid_encoding?
            new_str << char
          else
            new_str << '�'
          end
        end
      end

      # TODO: work with the debugger
      def initialize(streams)
        self.finish_criteria = FinishCriteria.new
        self.queue           = Queue.new
        event_stream         = streams.fetch :events
        stdout_stream        = streams.fetch :stdout
        stderr_stream        = streams.fetch :stderr

        Thread.new do
          stdout_stream.each_line { |line| queue << Events::Stdout.new(value: line) }
          queue << lambda { finish_criteria.stdout_thread_finished! }
        end

        Thread.new do
          stderr_stream.each_line { |line| queue << Events::Stderr.new(value: line) }
          queue << lambda { finish_criteria.stderr_thread_finished! }
        end

        Thread.new do
          begin           event_stream.each_line { |line| queue << line }
          rescue IOError; queue << lambda { raise WtfWhoClosedMyShit }
          ensure          queue << lambda { finish_criteria.event_thread_finished! }
          end
        end
      end

      def call(n=1)
        return next_event if n == 1
        Array.new(n) { next_event }
      end

      def each
        return to_enum :each unless block_given?
        loop { yield call(1) }
      rescue NoMoreEvents
      end

      # TODO: This could actually be dangerous,
      # b/c this is the thread that is consuming it,
      # so if it got full and blocked
      def process_exitstatus(status)
        queue << Events::Exitstatus.new(value: status)
        queue << lambda { finish_criteria.process_exited! }
      end

      private

      attr_accessor :queue, :finish_criteria

      def next_event
        raise NoMoreEvents if finish_criteria.satisfied?
        case element = queue.shift
        when String
          event_for element
        when Proc
          element.call
          next_event
        when Event
          element
        else
          raise "Uhhh... what's this thing here: #{element.inspect}"
        end
      end

      def extract_token(line)
        event_name = line[/[^ ]+/]
        line.sub! /^\s*[^ ]+\s*/, ''
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
          Events::UnrecordedResult.new(type: type, line_number: line_number)
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
