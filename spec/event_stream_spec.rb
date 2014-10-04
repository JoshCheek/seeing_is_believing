# encoding: utf-8

require 'seeing_is_believing/event_stream/producer'
require 'seeing_is_believing/event_stream/consumer'

module SeeingIsBelieving::EventStream
  RSpec.describe SeeingIsBelieving::EventStream do
    attr_accessor :producer, :consumer, :readstream, :writestream

    before do
      self.readstream, self.writestream = IO.pipe
      self.producer  = SeeingIsBelieving::EventStream::Producer.new(writestream)
      self.consumer  = SeeingIsBelieving::EventStream::Consumer.new(readstream)
    end

    after {
      producer.finish!
      readstream.close  unless readstream.closed?
      writestream.close unless writestream.closed?
    }

    describe 'emitting an event' do
      # TODO: could not fucking figure out how to ask the goddam thing if it has data
      # read docs for over an hour -.0
      it 'writes a line to stdout'

      # This test is irrelevant on MRI b/c of the GIL,
      # but I ran it on Rbx to make sure it works
      it 'is wrapped in a mutex to prevent multiple values from writing at the same time' do
        num_threads = 10
        num_results = 600
        line_nums_and_inspections = num_threads.times.flat_map { |line_num|
          num_results.times.map { |value| "#{line_num}|#{value.inspect}" }
        }

        producer_threads = num_threads.times.map { |line_num|
          Thread.new {
            num_results.times { |value| producer.record_result :type, line_num, value }
          }
        }

        (num_threads * num_results).times do |n|
          result = consumer.call
          ary_val = "#{result.line_number}|#{result.inspected}"
          index = line_nums_and_inspections.index(ary_val)
          raise "#{ary_val.inspect} is already consumed!" unless index
          line_nums_and_inspections.delete_at index
        end

        expect(line_nums_and_inspections).to eq []
        expect(producer_threads).to be_none(&:alive?)
      end

      it 'raises NoMoreInput and marks itself finished if input is closed before it finishes reading the number of requested inputs' do
        producer.finish!
        expect { consumer.call 10 }.to raise_error SeeingIsBelieving::EventStream::Consumer::NoMoreInput
      end

      it 'raises NoMoreInput and marks itself finished once it receives the finish event' do
        producer.finish!
        consumer.call 4
        expect { consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::NoMoreInput
        expect(consumer).to be_finished
      end

      it 'raises NoMoreInput and marks itself finished once the other end of the stream is closed' do
        writestream.close
        expect { consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::NoMoreInput
        expect(consumer).to be_finished
      end

      it 'raises WtfWhoClosedMyShit and marks itself finished if its end of the stream is closed' do
        readstream.close
        expect { consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::WtfWhoClosedMyShit
        expect(consumer).to be_finished
      end
    end

    describe 'each' do
      it 'loops through and yields all events except the finish event' do
        producer.record_result :inspect, 100, 2
        producer.finish!

        events = []
        consumer.each { |e| events << e }
        finish_event = events.find { |e| e.kind_of? Events::Finish }
        line_result  = events.find { |e| e.kind_of? Events::LineResult }
        exitstatus   = events.find { |e| e.kind_of? Events::Exitstatus }
        expect(finish_event).to be_nil
        expect(line_result.line_number).to eq 100
        expect(exitstatus.value).to eq 0
      end

      it 'stops looping if there is no more input' do
        writestream.close
        expect(consumer.each.map { |e| e }).to eq []
      end

      it 'returns nil' do
        producer.finish!
        expect(consumer.each { 1 }).to eq nil
      end

      it 'returns an enumerator if not given a block' do
        producer.finish!
        expect(consumer.each.map &:class).to include Events::Exitstatus
      end
    end


    describe 'record_results' do
      it 'emits a type, line_number, and escaped string' do
        producer.record_result :type1, 123, [*'a'..'z', *'A'..'Z', *'0'..'9'].join("")
        producer.record_result :type1, 123, '"'
        producer.record_result :type1, 123, '""'
        producer.record_result :type1, 123, "\n"
        producer.record_result :type1, 123, "\r"
        producer.record_result :type1, 123, "\n\r\n"
        producer.record_result :type1, 123, "\#{}"
        producer.record_result :type1, 123, [*0..127].map(&:chr).join("")
        producer.record_result :type1, 123, "Ω≈ç√∫˜µ≤≥"

        expect(consumer.call 9).to eq [
          Events::LineResult.new(:type1, 123, [*'a'..'z', *'A'..'Z', *'0'..'9'].join("").inspect),
          Events::LineResult.new(:type1, 123, '"'.inspect),
          Events::LineResult.new(:type1, 123, '""'.inspect),
          Events::LineResult.new(:type1, 123, "\n".inspect),
          Events::LineResult.new(:type1, 123, "\r".inspect),
          Events::LineResult.new(:type1, 123, "\n\r\n".inspect),
          Events::LineResult.new(:type1, 123, "\#{}".inspect),
          Events::LineResult.new(:type1, 123, [*0..127].map(&:chr).join("").inspect),
          Events::LineResult.new(:type1, 123, "Ω≈ç√∫˜µ≤≥".inspect),
        ]
      end

      it 'indicates that there are more results once it hits the max, but does not continue reporting them' do
        producer.max_line_captures = 2

        producer.record_result :type1, 123, 1
        expect(consumer.call 1).to eq Events::LineResult.new(:type1, 123, '1')

        producer.record_result :type1, 123, 2
        expect(consumer.call 1).to eq Events::LineResult.new(:type1, 123, '2')

        producer.record_result :type1, 123, 3
        producer.record_result :type1, 123, 4
        producer.record_result :type2, 123, 1
        expect(consumer.call 2).to eq [Events::UnrecordedResult.new(:type1, 123),
                                       Events::LineResult.new(:type2, 123, '1')]
      end

      it 'scopes the max to a given type/line' do
        producer.max_line_captures = 1

        producer.record_result :type1, 1, 1
        producer.record_result :type1, 1, 2
        producer.record_result :type1, 2, 3
        producer.record_result :type1, 2, 4
        producer.record_result :type2, 1, 5
        producer.record_result :type2, 1, 6
        expect(consumer.call 6).to eq [
          Events::LineResult.new(:type1, 1, '1'),
          Events::UnrecordedResult.new(:type1, 1),
          Events::LineResult.new(:type1, 2, '3'),
          Events::UnrecordedResult.new(:type1, 2),
          Events::LineResult.new(:type2, 1, '5'),
          Events::UnrecordedResult.new(:type2, 1),
        ]
      end

      it 'returns the value' do
        o = Object.new
        expect(producer.record_result :type, 123, o).to equal o
      end

      # Some examples, mostly for the purpose of running individually if things get confusing
      example 'Example: Simple' do
        producer.record_result :type, 1, "a"
        expect(consumer.call).to eq Events::LineResult.new(:type, 1, '"a"')

        producer.record_result :type, 1, 1
        expect(consumer.call).to eq Events::LineResult.new(:type, 1, '1')
      end

      example 'Example: Complex' do
        str1 = (0...128).map(&:chr).join('') << "Ω≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
        str2 = str1.dup
        producer.record_result :type, 1, str2
        expect(str2).to eq str1 # just making sure it doesn't mutate since this one is so complex
        expect(consumer.call).to eq Events::LineResult.new(:type, 1, str1.inspect)
      end

      context 'calls #inspect when no block is given' do
        it "doesn't blow up when there is no #inspect available e.g. BasicObject" do
          obj = BasicObject.new
          producer.record_result :type, 1, obj
          expect(consumer.call).to eq Events::LineResult.new(:type, 1, "#<no inspect available>")
        end


        it "doesn't blow up when #inspect returns a not-String (e.g. pathalogical libraries like FactoryGirl)" do
          obj = BasicObject.new
          def obj.inspect
            nil
          end
          producer.record_result :type, 1, obj
          expect(consumer.call).to eq Events::LineResult.new(:type, 1, "#<no inspect available>")
        end

        it 'only calls inspect once' do
          count, obj = 0, Object.new
          obj.define_singleton_method :inspect do
            count += 1
            'a'
          end
          producer.record_result :type, 1, obj
          expect(count).to eq 1
        end
      end

      context 'inspect performed by the block' do
        it 'yields the object to the block and uses the block\'s result as the inspect value instead of calling inspect' do
          o = Object.new
          def o.inspect()       'real-inspect'  end
          def o.other_inspect() 'other-inspect' end
          producer.record_result(:type, 1, o) { |x| x.other_inspect }
          expect(consumer.call).to eq Events::LineResult.new(:type, 1, 'other-inspect')
        end

        it 'doesn\'t blow up if the block raises' do
          o = Object.new
          producer.record_result(:type, 1, o) { raise Exception, "zomg" }
          expect(consumer.call).to eq Events::LineResult.new(:type, 1, '#<no inspect available>')
        end

        it 'doesn\'t blow up if the block returns a non-string' do
          o = Object.new
          producer.record_result(:type, 1, o) { nil }
          expect(consumer.call).to eq Events::LineResult.new(:type, 1, '#<no inspect available>')

          stringish = Object.new
          def stringish.to_str() 'actual string' end
          producer.record_result(:type, 1, o) { stringish }
          expect(consumer.call).to eq Events::LineResult.new(:type, 1, 'actual string')
        end

        it 'invokes the block only once' do
          o = Object.new
          count = 0

          producer.record_result(:type, 1, o) { count += 1 }
          expect(count).to eq 1

          producer.record_result(:type, 1, o) { count += 1; 'inspected-value' }
          expect(count).to eq 2
        end
      end
    end

    describe 'exceptions' do
      def assert_exception(recorded_exception, options={})
        expect(recorded_exception).to be_a_kind_of Events::Exception
        expect(recorded_exception.line_number).to eq    options[:recorded_line_no]
        expect(recorded_exception.class_name ).to match options[:class_name_matcher] if options[:class_name_matcher]
        expect(recorded_exception.message    ).to match options[:message_matcher]    if options[:message_matcher]

        backtrace = recorded_exception.backtrace
        expect(backtrace).to be_a_kind_of Array
        expect(backtrace).to be_all { |frame| String === frame }
        frame = backtrace[options[:backtrace_index]||0]
        expect(frame).to match /(^|\b)#{options[:backtrace_filename]}(\b|$)/ if options[:backtrace_filename]
        expect(frame).to match /(^|\b)#{options[:backtrace_line]}(\b|$)/     if options[:backtrace_line]
      end

      it 'emits the line_number, an escaped class_name, an escaped message, and escaped backtrace' do
        begin
          raise ZeroDivisionError, 'omg'
        rescue
          producer.record_exception 12, $!
        end
        assert_exception consumer.call,
                         recorded_line_no:   12,
                         class_name_matcher: /^ZeroDivisionError$/,
                         message_matcher:    /\Aomg\Z/,
                         backtrace_index:    0,
                         backtrace_line:     (__LINE__-9),
                         backtrace_filename: __FILE__
      end

      example 'Example: Common edge case: name error' do
        begin
          not_a_local_or_meth
        rescue
          producer.record_exception 99, $!
        end
        backtrace_frame = 1 # b/c this one will get caught by method missing
        assert_exception consumer.call,
                         recorded_line_no:   99,
                         class_name_matcher: /^NameError$/,
                         message_matcher:    /\bnot_a_local_or_meth\b/,
                         backtrace_index:    1,
                         backtrace_line:     (__LINE__-10),
                         backtrace_filename: __FILE__
      end

      it 'sets the exit status if the exception is a SystemExit' do
        begin
          exit 22
        rescue SystemExit
          producer.record_exception 12, $!
        end
        expect(producer.exitstatus).to eq 22
      end

      it 'sets the exit status to 0 if the exception is not a SystemExit' do
        expect(producer.exitstatus).to eq 0
        begin
          raise
        rescue RuntimeError
          producer.record_exception nil, $!
        end
        expect(producer.exitstatus).to eq 1
      end

      let(:exception) { begin; raise "zomg"; rescue; $!; end }
      let(:linenum)   { __LINE__ - 1 }
      it "uses provided line num        when: | line num is provided  | knows file        | exception comes from within file" do
        producer.filename = __FILE__
        producer.record_exception 12, exception
        assert_exception consumer.call, recorded_line_no: 12
      end
      it "uses provided line num        when: | line num is provided  | knows file        | exception comes from elsewhere" do
        exception.backtrace.replace ['otherfile.rb']
        producer.record_exception 12, exception
        producer.filename = __FILE__
        assert_exception consumer.call, recorded_line_no: 12
      end
      it "uses provided line num        when: | line num is provided  | doesn't know file | exception comes from within file" do
        producer.filename = nil
        producer.record_exception 12, exception
        assert_exception consumer.call, recorded_line_no: 12
      end
      it "uses provided line num        when: | line num is provided  | doesn't know file | exception comes from elsewhere" do
        exception.backtrace.replace ['otherfile.rb']
        producer.filename = nil
        producer.record_exception 12, exception
        assert_exception consumer.call, recorded_line_no: 12
      end
      it "finds line num from backtrace when: | line num not provided | knows file        | exception comes from within file" do
        producer.filename = __FILE__
        producer.record_exception nil, exception
        assert_exception consumer.call, recorded_line_no: linenum
      end
      it "line num is -1                when: | line num not provided | knows file        | exception comes from elsewhere" do
        exception.backtrace.replace ['otherfile.rb']
        producer.filename = __FILE__
        producer.record_exception nil, exception
        assert_exception consumer.call, recorded_line_no: -1
      end
      it "line num is -1                when: | line num not provided | doesn't know file | exception comes from within file" do
        producer.filename = nil
        producer.record_exception nil, exception
        assert_exception consumer.call, recorded_line_no: -1
      end
      it "line num is -1                when: | line num not provided | doesn't know file | exception comes from elsewhere" do
        exception.backtrace.replace ['otherfile.rb']
        producer.filename = nil
        producer.record_exception nil, exception
        assert_exception consumer.call, recorded_line_no: -1
      end
    end

    describe 'stdout' do
      it 'is an escaped string' do
        producer.record_stdout("this is the stdout¡")
        expect(consumer.call).to eq Events::Stdout.new("this is the stdout¡")
      end
    end

    describe 'stderr' do
      it 'is an escaped string' do
        producer.record_stderr("this is the stderr¡")
        expect(consumer.call).to eq Events::Stderr.new("this is the stderr¡")
      end
    end

    describe 'finish!' do
      def final_event(producer, consumer, event_class)
        producer.finish!
        consumer.call(4).find { |e| e.class == event_class }
      end

      describe 'max_line_captures' do
        it 'interprets numbers' do
          producer.max_line_captures = 12
          expect(final_event(producer, consumer, Events::MaxLineCaptures).value).to eq 12
        end

        it 'interprets infinity' do
          producer.max_line_captures = Float::INFINITY
          expect(final_event(producer, consumer, Events::MaxLineCaptures).value).to eq Float::INFINITY
        end

        it 'is infinity by default' do
          expect(final_event(producer, consumer, Events::MaxLineCaptures).value).to eq Float::INFINITY
        end
      end

      describe 'num_lines' do
        it 'interprets numbers' do
          producer.num_lines = 21
          expect(final_event(producer, consumer, Events::NumLines).value).to eq 21
        end

        it 'is 0 by default' do
          expect(final_event(producer, consumer, Events::NumLines).value).to eq 0
        end

        it 'updates its value if it sees a result from a line larger than its value' do
          producer.num_lines = 2
          producer.record_result :sometype, 100, :someval
          expect(final_event(producer, consumer, Events::NumLines).value).to eq 100
        end

        it 'updates its value if it sees an exception from a line larger than its value' do
          producer.num_lines = 2
          begin; raise; rescue; e = $!; end
          producer.record_exception 100, e
          expect(final_event(producer, consumer, Events::NumLines).value).to eq 100
        end
      end

      describe 'exitstatus' do
        it 'is 0 by default' do
          expect(final_event(producer, consumer, Events::Exitstatus).value).to eq 0
        end

        it 'can be overridden' do
          producer.exitstatus = 74
          expect(final_event(producer, consumer, Events::Exitstatus).value).to eq 74
        end
      end

      describe 'finish' do
        it 'is the last thing that will be read' do
          expect(final_event(producer, consumer, Events::Finish)).to be_a_kind_of Events::Finish
          expect { p consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::NoMoreInput
        end
      end
    end
  end
end
