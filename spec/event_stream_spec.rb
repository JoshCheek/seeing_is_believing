require 'seeing_is_believing/event_stream'

RSpec.describe SeeingIsBelieving::EventStream do
  LineResult       = SeeingIsBelieving::EventStream::Event::LineResult
  StdoutResult     = SeeingIsBelieving::EventStream::Event::StdoutResult
  StderrResult     = SeeingIsBelieving::EventStream::Event::StderrResult
  ExceptionResult  = SeeingIsBelieving::EventStream::Event::ExceptionResult
  UnrecordedResult = SeeingIsBelieving::EventStream::Event::UnrecordedResult
  BugInSiB         = SeeingIsBelieving::EventStream::Event::BugInSiBResult

  attr_accessor :publisher, :consumer, :readstream, :writestream

  before do
    self.readstream, self.writestream = IO.pipe
    self.publisher = SeeingIsBelieving::EventStream::Publisher.new(writestream)
    self.consumer  = SeeingIsBelieving::EventStream::Consumer.new(readstream)
  end

  after {
    readstream.close  unless readstream.closed?
    writestream.close unless writestream.closed?
  }

  # TODO: could not fucking figure out how to ask the goddam thing if it has data
  # read docs for over an hour -.0
  describe 'emitting a result' do
    it 'writes a line to stdout'
    it 'is wrapped in a mutex to prevent multiple values from writing at the same time'
  end

  describe 'record_results' do
    it 'emits a type, line_number, and escaped string' do
      publisher.record_result :type1, 123, [*'a'..'z', *'A'..'Z', *'0'..'9'].join("")
      publisher.record_result :type1, 123, '"'
      publisher.record_result :type1, 123, '""'
      publisher.record_result :type1, 123, "\n"
      publisher.record_result :type1, 123, "\r"
      publisher.record_result :type1, 123, "\n\r\n"
      publisher.record_result :type1, 123, "\#{}"
      publisher.record_result :type1, 123, [*0..127].map(&:chr).join("")
      publisher.record_result :type1, 123, "Ω≈ç√∫˜µ≤≥"

      expect(consumer.call 9).to eq [
        LineResult.new(:type1, 123, [*'a'..'z', *'A'..'Z', *'0'..'9'].join("").inspect),
        LineResult.new(:type1, 123, '"'.inspect),
        LineResult.new(:type1, 123, '""'.inspect),
        LineResult.new(:type1, 123, "\n".inspect),
        LineResult.new(:type1, 123, "\r".inspect),
        LineResult.new(:type1, 123, "\n\r\n".inspect),
        LineResult.new(:type1, 123, "\#{}".inspect),
        LineResult.new(:type1, 123, [*0..127].map(&:chr).join("").inspect),
        LineResult.new(:type1, 123, "Ω≈ç√∫˜µ≤≥".inspect),
      ]
    end

    it 'indicates that there are more results once it hits the max, but does not continue reporting them' do
      publisher.max_line_captures = 2

      publisher.record_result :type1, 123, 1
      expect(consumer.call 1).to eq LineResult.new(:type1, 123, '1')

      publisher.record_result :type1, 123, 2
      expect(consumer.call 1).to eq LineResult.new(:type1, 123, '2')

      publisher.record_result :type1, 123, 3
      publisher.record_result :type1, 123, 4
      publisher.record_result :type2, 123, 1
      expect(consumer.call 2).to eq [UnrecordedResult.new(:type1, 123),
                                     LineResult.new(:type2, 123, '1')]
    end

    it 'scopes the max to a given type/line' do
      publisher.max_line_captures = 1

      publisher.record_result :type1, 1, 1
      publisher.record_result :type1, 1, 2
      publisher.record_result :type1, 2, 3
      publisher.record_result :type1, 2, 4
      publisher.record_result :type2, 1, 5
      publisher.record_result :type2, 1, 6
      expect(consumer.call 6).to eq [
        LineResult.new(:type1, 1, '1'),
        UnrecordedResult.new(:type1, 1),
        LineResult.new(:type1, 2, '3'),
        UnrecordedResult.new(:type1, 2),
        LineResult.new(:type2, 1, '5'),
        UnrecordedResult.new(:type2, 1),
      ]
    end

    it 'returns the value' do
      o = Object.new
      expect(publisher.record_result :type, 123, o).to equal o
    end

    # Some examples, mostly for the purpose of running individually if things get confusing
    example 'Example: Simple' do
      publisher.record_result :type, 1, "a"
      expect(consumer.call).to eq LineResult.new(:type, 1, '"a"')

      publisher.record_result :type, 1, 1
      expect(consumer.call).to eq LineResult.new(:type, 1, '1')
    end

    example 'Example: Complex' do
      str1 = (0...128).map(&:chr).join('') << "Ω≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
      str2 = str1.dup
      publisher.record_result :type, 1, str2
      expect(str2).to eq str1 # just making sure it doesn't mutate since this one is so complex
      expect(consumer.call).to eq LineResult.new(:type, 1, str1.inspect)
    end
  end

  describe 'exceptions' do
    def assert_exception(recorded_exception, recorded_line_no, class_name, message_matcher, backtrace_index, backtrace_line)
      expect(recorded_exception).to be_a_kind_of ExceptionResult
      expect(recorded_exception.line_number).to eq recorded_line_no
      expect(recorded_exception.class_name).to  eq class_name
      expect(recorded_exception.message).to match message_matcher

      backtrace = recorded_exception.backtrace
      expect(backtrace).to be_a_kind_of Array
      expect(backtrace).to be_all { |frame| String === frame }
      frame = backtrace[backtrace_index]
      expect(frame).to match __FILE__
      expect(frame).to match /\b#{backtrace_line}\b/
    end

    it 'emits the line_number, an escaped class_name, an escaped message, and escaped backtrace' do
      begin
        raise ZeroDivisionError, 'omg'
      rescue
        publisher.record_exception 12, $!
      end
      assert_exception consumer.call, 12, 'ZeroDivisionError', /\Aomg\Z/, 0, __LINE__-4
    end

    example 'Example: Common edge case: name error' do
      begin
        not_a_local_or_meth
      rescue
        publisher.record_exception 99, $!
      end
      backtrace_frame = 1 # b/c this one will get caught by method missing
      assert_exception consumer.call, 99, 'NameError', /\bnot_a_local_or_meth\b/, 1, __LINE__-5
    end
  end

  describe 'stdout' do
    it 'is an escaped string' do
      publisher.record_stdout("this is the stdout¡")
      expect(consumer.call).to eq StdoutResult.new("this is the stdout¡")
    end
  end

  describe 'stderr' do
    it 'is an escaped string' do
      publisher.record_stderr("this is the stderr¡")
      expect(consumer.call).to eq StderrResult.new("this is the stderr¡")
    end
  end

  describe 'finalize' do
    # TODO: Should there also be an event for being complete (ie you can stop listening now)?
    def final_event(publisher, consumer, event_class)
      publisher.finalize
      consumer.call(3).find { |e| e.class == event_class }
    end

    describe 'bug_in_sib' do
      it 'truthy values are transated to true' do
        publisher.bug_in_sib = 'a value'
        expect(final_event(publisher, consumer, BugInSiB).value).to equal true
      end

      it 'falsy values are translated to false' do
        publisher.bug_in_sib = nil
        expect(final_event(publisher, consumer, BugInSiB).value).to equal false
      end

      it 'is false by default, and is always emitted' do
        expect(final_event(publisher, consumer, BugInSiB).value).to equal false
      end
    end

    describe 'max_line_captures' do
      it 'interprets numbers'
      it 'interprets infinity'
      it 'is infinity by default'
    end

    describe 'exitstatus' do
      it 'is 0 by default'
      it 'can be overridden'
    end
  end
end
