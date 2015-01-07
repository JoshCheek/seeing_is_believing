# encoding: utf-8

require 'seeing_is_believing/event_stream/producer'
require 'seeing_is_believing/event_stream/consumer'

module SeeingIsBelieving::EventStream
  RSpec.describe SeeingIsBelieving::EventStream do
    attr_accessor :producer, :consumer
    attr_accessor :eventstream_consumer, :eventstream_producer
    attr_accessor :stdout_consumer, :stdout_producer
    attr_accessor :stderr_consumer, :stderr_producer

    def close_streams(*streams)
      streams.each { |fd| fd.close unless fd.closed? }
    end

    def finish!
      producer.finish!
      close_streams eventstream_producer, stdout_producer, stderr_producer
    end

    before do
      self.eventstream_consumer, self.eventstream_producer = IO.pipe
      self.stdout_consumer,      self.stdout_producer      = IO.pipe
      self.stderr_consumer,      self.stderr_producer      = IO.pipe

      self.producer = SeeingIsBelieving::EventStream::Producer.new eventstream_producer
      self.consumer = SeeingIsBelieving::EventStream::Consumer.new \
        events: eventstream_consumer,
        stdout: stdout_consumer,
        stderr: stderr_consumer
    end

    after do
      finish!
      close_streams eventstream_consumer, stdout_consumer, stderr_consumer
    end

    describe 'emitting an event' do
      def has_message?(io)
        io.read_nonblock(1)  # ~> IO::EAGAINWaitReadable: Resource temporarily unavailable - read would block
      rescue Errno::EAGAIN
        return false
      end

      it 'writes its events to the event stream' do
        read, write = IO.pipe
        producer = SeeingIsBelieving::EventStream::Producer.new(write)
        expect(has_message? read).to eq false
        producer.record_filename "whatever.rb"
        expect(read.gets).to start_with 'filename'
      end

      # This test is irrelevant on MRI b/c of the GIL, but I ran it on Rbx to make sure it works
      it 'is threadsafe as multiple events can occur at once' do
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

      it 'transcodes any received messages to UTF8' do
        utf8  = "こんにちは" # from https://github.com/svenfuchs/i18n/blob/ee7fef8e9b9ee2f7d16e6c36d669ee7fb24ec613/lib/i18n/tests/interpolation.rb#L72
        eucjp = utf8.encode(Encoding::EUCJP)
        producer.record_sib_version(eucjp)
        version = consumer.call.value
        expect(version).to eq utf8
        expect(version).to_not eq eucjp          # general sanity checks to make
        expect(utf8.bytes).to_not eq eucjp.bytes # sure I don't accidentally pass
      end

      def ascii8bit(str)
        str.force_encoding Encoding::ASCII_8BIT
      end

      it 'force encodes the message to UTF8 when it can\'t validly transcode' do
        producer.record_sib_version(ascii8bit("åß∂ƒ"))
        version = consumer.call.value
        expect(version).to eq "åß∂ƒ"
        expect(version).to_not eq ascii8bit("åß∂ƒ")
      end

      it 'scrubs any invalid bytes to "�" when the force encoding isn\'t valid' do
        producer.record_sib_version(ascii8bit "a\xFF å")  # unicode bytes can't begin with
        expect(consumer.call.value).to eq "a� å"          # space just so its easier to see
      end

      it 'raises NoMoreInput if input is closed before it finishes reading the number of requested inputs' do
        finish!
        expect { consumer.call 10 }.to raise_error SeeingIsBelieving::EventStream::Consumer::NoMoreInput
      end

      it 'raises NoMoreInput once it its input streams are all closed' do
        producer.finish!
        close_streams eventstream_producer, stdout_producer, stderr_producer
        consumer.call 2
        expect { consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::NoMoreInput
      end

      it 'raises NoMoreInput if its end of the stream is closed and there is no more stdout/stderr' do
        close_streams eventstream_consumer, stdout_producer, stderr_producer
        expect { consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::WtfWhoClosedMyShit
        expect { consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::NoMoreInput
      end

      it 'raises WtfWhoClosedMyShit if its end of the stream is closed' do
        close_streams eventstream_consumer, stdout_producer, stderr_producer
        expect { consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::WtfWhoClosedMyShit
      end

      specify 'if an incomprehensible event is received, it raises an UnknownEvent' do
        eventstream_producer.puts "this is nonsense!"
        eventstream_producer.close
        expect{ consumer.call }.to raise_error SeeingIsBelieving::EventStream::Consumer::UnknownEvent, /nonsense/
      end
    end

    describe 'each' do
      it 'loops through and yields all events' do
        producer.record_result :inspect, 100, 2
        finish!

        events = []
        consumer.each { |e| events << e }
        line_result  = events.find { |e| e.kind_of? Events::LineResult }
        exitstatus   = events.find { |e| e.kind_of? Events::Exitstatus }
        expect(line_result.line_number).to eq 100
        expect(exitstatus.value).to eq 0
      end

      it 'stops looping if there is no more input' do
        finish!
        expect(consumer.each.map { |e| e }).to eq [
          Events::NumLines.new(0),
          Events::Exitstatus.new(0),
        ]
      end

      it 'returns nil' do
        finish!
        expect(consumer.each { 1 }).to eq nil
      end

      it 'returns an enumerator if not given a block' do
        finish!
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

    describe 'max_line_captures (value and recording)' do
      it 'is infinity by default' do
        expect(producer.max_line_captures).to eq Float::INFINITY
      end

      it 'emits the event and sets the max_line_captures' do
        producer.record_max_line_captures 123
        expect(producer.max_line_captures).to eq 123
        expect(consumer.call).to eq Events::MaxLineCaptures.new(123)
      end

      it 'interprets numbers' do
        producer.record_max_line_captures 12
        expect(consumer.call).to eq Events::MaxLineCaptures.new(12)
      end

      it 'interprets infinity' do
        producer.record_max_line_captures Float::INFINITY
        expect(consumer.call).to eq Events::MaxLineCaptures.new(Float::INFINITY)
      end
    end


    describe 'exceptions' do
      def record_exception(linenum=nil, &raises_exception)
        raises_exception.call
      rescue Exception
        producer.record_exception linenum, $!
        return raises_exception.source_location.last
      end

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
        backtrace_line = record_exception(12) { raise ZeroDivisionError, 'omg' }
        assert_exception consumer.call,
                         recorded_line_no:   12,
                         class_name_matcher: /^ZeroDivisionError$/,
                         message_matcher:    /\Aomg\Z/,
                         backtrace_index:    0,
                         backtrace_line:     backtrace_line,
                         backtrace_filename: __FILE__
      end

      example 'Example: Common edge case: name error' do
        backtrace_line  = record_exception(99) { not_a_local_or_meth }
        backtrace_frame = 1 # b/c this one will get caught by rspec's method missing
        assert_exception consumer.call,
                         recorded_line_no:   99,
                         class_name_matcher: /^NameError$/,
                         message_matcher:    /\bnot_a_local_or_meth\b/,
                         backtrace_index:    1,
                         backtrace_line:     backtrace_line,
                         backtrace_filename: __FILE__
      end

      context 'when the exception is a SystemExit' do
        it 'sets the exit status to the one provided' do
          record_exception { exit 22 }
          expect(producer.exitstatus).to eq 22
        end

        it 'sets the exit status to 0 or 1 if exited with true or false' do
          expect(producer.exitstatus).to eq 0
          record_exception { exit true }
          expect(producer.exitstatus).to eq 0
          record_exception { exit false }
          expect(producer.exitstatus).to eq 1
        end

        it 'sets the exit status to 1 if the exception is not a SystemExit' do
          expect(producer.exitstatus).to eq 0
          record_exception { raise }
          expect(producer.exitstatus).to eq 1
        end
      end

      context 'recorded line number | line num is provided | it knows the file | exception comes from within file' do
        let(:exception) { begin; raise "zomg"; rescue; $!; end }
        let(:linenum)   { __LINE__ - 1 }
        example "provided one       | true                 | true              | true" do
          producer.filename = __FILE__
          producer.record_exception 12, exception
          assert_exception consumer.call, recorded_line_no: 12
        end
        example "provided one       | true                 | true              | false" do
          exception.backtrace.replace ['otherfile.rb']
          producer.record_exception 12, exception
          producer.filename = __FILE__
          assert_exception consumer.call, recorded_line_no: 12
        end
        example "provided one       | true                 | false             | true" do
          producer.filename = nil
          producer.record_exception 12, exception
          assert_exception consumer.call, recorded_line_no: 12
        end
        example "provided one       | true                 | false             | false" do
          exception.backtrace.replace ['otherfile.rb']
          producer.filename = nil
          producer.record_exception 12, exception
          assert_exception consumer.call, recorded_line_no: 12
        end
        example "from backtrace     | false                | true              | true" do
          producer.filename = __FILE__
          producer.record_exception nil, exception
          assert_exception consumer.call, recorded_line_no: linenum
        end
        example "-1                 | false                | true              | false" do
          exception.backtrace.replace ['otherfile.rb']
          producer.filename = __FILE__
          producer.record_exception nil, exception
          assert_exception consumer.call, recorded_line_no: -1
        end
        example "-1                 | false                | false             | true" do
          producer.filename = nil
          producer.record_exception nil, exception
          assert_exception consumer.call, recorded_line_no: -1
        end
        example "-1                 | false                | false             | false" do
          exception.backtrace.replace ['otherfile.rb']
          producer.filename = nil
          producer.record_exception nil, exception
          assert_exception consumer.call, recorded_line_no: -1
        end
      end
    end

    describe 'seeing is believing version' do
      describe 'recording the version' do
        it 'emits the version info' do
          producer.record_sib_version '1.2.3'
          expect(consumer.call).to eq Events::SiBVersion.new("1.2.3")
        end
      end

      specify 'version return the version, if it has been set' do
        expect(producer.version).to eq nil
        producer.record_sib_version '4.5.6'
        expect(producer.version).to eq '4.5.6'
      end
    end

    describe 'record_ruby_version' do
      it 'emits the ruby version info' do
        producer.record_ruby_version 'o.m.g.'
        expect(consumer.call).to eq Events::RubyVersion.new('o.m.g.')
      end
    end

    describe 'record_filename' do
      it 'sets the filename' do
        producer.record_filename 'this-iz-mah-file.rb'
        expect(producer.filename).to eq 'this-iz-mah-file.rb'
      end
      it 'emits the filename' do
        producer.record_filename 'this-iz-mah-file.rb'
        expect(consumer.call).to eq Events::Filename.new('this-iz-mah-file.rb')
      end
    end

    describe 'stdout' do
      it 'is emitted along with the events from the event stream' do
        stdout_producer.puts "this is the stdout¡"
        expect(consumer.call).to eq Events::Stdout.new("this is the stdout¡\n")
      end
      specify 'each line is emitted as an event' do
        stdout_producer.puts "first"
        stdout_producer.puts "second\nthird"
        expect(consumer.call).to eq Events::Stdout.new("first\n")
        expect(consumer.call).to eq Events::Stdout.new("second\n")
        expect(consumer.call).to eq Events::Stdout.new("third\n")
      end
    end

    describe 'stderr' do
      it 'is emitted along with the events from the event stream' do
        stderr_producer.puts "this is the stderr¡"
        expect(consumer.call).to eq Events::Stderr.new("this is the stderr¡\n")
      end
      specify 'each line is emitted as an event' do
        stderr_producer.puts "first"
        stderr_producer.puts "second\nthird"
        expect(consumer.call).to eq Events::Stderr.new("first\n")
        expect(consumer.call).to eq Events::Stderr.new("second\n")
        expect(consumer.call).to eq Events::Stderr.new("third\n")
      end
    end


    describe 'finish!' do
      def final_event(producer, consumer, event_class)
        finish!
        consumer.call(2).find { |e| e.class == event_class }
      end

      it 'stops the producer from producing' do
        read, write = IO.pipe
        producer = SeeingIsBelieving::EventStream::Producer.new write
        producer.finish!
        read.gets
        read.gets
        producer.record_filename("zomg")
        write.close
        expect(read.gets).to eq nil
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
    end
  end
end
