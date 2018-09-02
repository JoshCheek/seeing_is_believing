# encoding: utf-8

require 'seeing_is_believing/event_stream/producer'
require 'seeing_is_believing/event_stream/consumer'
require 'seeing_is_believing/event_stream/handlers/debug'
require 'seeing_is_believing/debugger'

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
      consumer.process_exitstatus(0)
      close_streams eventstream_producer, stdout_producer, stderr_producer
      consumer.join
    end

    def inspected(obj)
      Kernel.instance_method(:inspect).bind(obj).call
    end


    before do
      self.eventstream_consumer, self.eventstream_producer = IO.pipe("utf-8")
      self.stdout_consumer,      self.stdout_producer      = IO.pipe("utf-8")
      self.stderr_consumer,      self.stderr_producer      = IO.pipe("utf-8")

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
        readables, * = IO.select([io], [], [], 0.1) # 0.1 is the timeout
        readables.to_a.any? # when it times out, IO.select may return nil...
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

      it 'scrubs any invalid bytes to "�" when encoding was already UTF8, but was invalid' do
        producer.record_sib_version("\xff√")
        expect(consumer.call.value).to eq "�√"
      end

      it 'raises NoMoreEvents if input is closed before it finishes reading the number of requested inputs' do
        finish!
        expect { consumer.call 10 }.to raise_error SeeingIsBelieving::NoMoreEvents
      end

      it 'raises NoMoreEvents once its input streams are all closed and its seen an exit status' do
        close_streams eventstream_producer, stdout_producer, stderr_producer
        consumer.process_exitstatus 0
        consumer.each { }
        expect { consumer.call }.to raise_error SeeingIsBelieving::NoMoreEvents
      end

      it 'raises NoMoreEvents once its input streams are all closed and its seen a timeout' do
        close_streams eventstream_producer, stdout_producer, stderr_producer
        consumer.process_timeout 1
        consumer.each { }
        expect { consumer.call }.to raise_error SeeingIsBelieving::NoMoreEvents
      end

      it 'gracefully handles its side of the streams getting closed' do
        close_streams eventstream_consumer, stdout_consumer, stderr_consumer
        consumer.process_exitstatus 0
        consumer.each { }
        expect { consumer.call }.to raise_error SeeingIsBelieving::NoMoreEvents
      end

      specify 'if an incomprehensible event is received, it raises an UnknownEvent' do
        eventstream_producer.puts "this is nonsense!"
        expect{ consumer.call }.to raise_error SeeingIsBelieving::UnknownEvent, /nonsense/
      end
    end

    describe 'each' do
      it 'loops through and yields all events' do
        # declare 2 events
        producer.record_result :inspect, 100, 2
        producer.record_sib_version('some ver')

        # close streams so that it won't block waiting for more events
        finish!

        # record events
        events = []
        consumer.each { |e| events << e }

        # it yielded the line result
        line_result = events.find { |e| e.kind_of? Events::LineResult }
        expect(line_result.line_number).to eq 100

        # it yielded the version
        version = events.find { |e| e.kind_of? Events::SiBVersion }
        expect(version.value).to eq 'some ver'
      end

      it 'stops looping if there is no more input' do
        producer.record_result :inspect, 100, 2
        producer.record_sib_version('some ver')
        finish!
        expect(consumer.each.map { |e| e.class }.sort_by(&:to_s))
          .to eq [ Events::EventStreamClosed, Events::Exitstatus,   Events::Finished,
                   Events::LineResult,        Events::SiBVersion, Events::StderrClosed, Events::StdoutClosed,
                 ]
      end

      it 'returns nil' do
        finish!
        expect(consumer.each { 1 }).to eq nil
      end

      it 'returns an enumerator if not given a block' do
        producer.record_sib_version('some ver')
        finish!
        classes = consumer.each.map &:class
        expect(classes).to include Events::SiBVersion
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
          Events::LineResult.new(type: :type1, line_number: 123, inspected: [*'a'..'z', *'A'..'Z', *'0'..'9'].join("").inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: '"'.inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: '""'.inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: "\n".inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: "\r".inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: "\n\r\n".inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: "\#{}".inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: [*0..127].map(&:chr).join("").inspect),
          Events::LineResult.new(type: :type1, line_number: 123, inspected: "Ω≈ç√∫˜µ≤≥".inspect),
        ]
      end

      it 'indicates that there are more results once it hits the max, but does not continue reporting them' do
        producer.max_line_captures = 2

        producer.record_result :type1, 123, 1
        expect(consumer.call 1).to eq Events::LineResult.new(type: :type1, line_number: 123, inspected: '1')

        producer.record_result :type1, 123, 2
        expect(consumer.call 1).to eq Events::LineResult.new(type: :type1, line_number: 123, inspected: '2')

        producer.record_result :type1, 123, 3
        producer.record_result :type1, 123, 4
        producer.record_result :type2, 123, 1
        expect(consumer.call 2).to eq [Events::ResultsTruncated.new(type: :type1, line_number: 123),
                                       Events::LineResult.new(type: :type2, line_number: 123, inspected: '1')]
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
          Events::LineResult.new(      type: :type1, line_number: 1, inspected: '1'),
          Events::ResultsTruncated.new(type: :type1, line_number: 1),
          Events::LineResult.new(      type: :type1, line_number: 2, inspected: '3'),
          Events::ResultsTruncated.new(type: :type1, line_number: 2),
          Events::LineResult.new(      type: :type2, line_number: 1, inspected: '5'),
          Events::ResultsTruncated.new(type: :type2, line_number: 1),
        ]
      end

      it 'returns the value' do
        o = Object.new
        expect(producer.record_result :type, 123, o).to equal o
      end

      # Some examples, mostly for the purpose of running individually if things get confusing
      example 'Example: Simple' do
        producer.record_result :type, 1, "a"
        expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: '"a"')

        producer.record_result :type, 1, 1
        expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: '1')
      end

      example 'Example: Complex' do
        str1 = (0...128).map(&:chr).join('') << "Ω≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
        str2 = str1.dup
        producer.record_result :type, 1, str2
        expect(str2).to eq str1 # just making sure it doesn't mutate since this one is so complex
        expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: str1.inspect)
      end

      context 'calls #inspect when no block is given' do
        it 'uses Kernel\'s inspect if there is no #inspect available e.g. BasicObject' do
          obj = BasicObject.new
          producer.record_result :type, 1, obj
          expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: inspected(obj))
        end

        it "uses Kernel's #inspect when the object\'s #inspect returns a not-String (e.g. pathalogical libraries like FactoryGirl)" do
          obj = BasicObject.new
          def obj.inspect
            nil
          end
          producer.record_result :type, 1, obj
          expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: inspected(obj))
        end

        it "uses a null-inspect string when even Kernel's inspect doesn't work" do
          skip 'uhm, no idea how to get it into such a state'
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

        it 'can deal with results of inspect that have singleton methods' do
          str = "a string"
          def str.inspect() self end
          producer.record_result :type, 1, str
          expect(consumer.call.inspected).to eq str
        end
      end

      context 'inspect performed by the block' do
        it 'yields the object to the block and uses the block\'s result as the inspect value instead of calling inspect' do
          o = Object.new
          def o.inspect()       'real-inspect'  end
          def o.other_inspect() 'other-inspect' end
          producer.record_result(:type, 1, o) { |x| x.other_inspect }
          expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: 'other-inspect')
        end

        it 'doesn\'t blow up if the block raises' do
          o = Object.new
          producer.record_result(:type, 1, o) { raise Exception, "zomg" }
          expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: inspected(o))
        end

        it 'doesn\'t blow up if the block returns a non-string' do
          o = Object.new
          producer.record_result(:type, 1, o) { nil }
          expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: inspected(o))

          stringish = Object.new
          def stringish.to_str() 'actual string' end
          producer.record_result(:type, 1, o) { stringish }
          expect(consumer.call).to eq Events::LineResult.new(type: :type, line_number: 1, inspected: 'actual string')
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
        expect(consumer.call).to eq Events::MaxLineCaptures.new(value: 123)
      end

      it 'interprets numbers' do
        producer.record_max_line_captures 12
        expect(consumer.call).to eq Events::MaxLineCaptures.new(value: 12)
      end

      it 'interprets infinity' do
        producer.record_max_line_captures Float::INFINITY
        expect(consumer.call).to eq Events::MaxLineCaptures.new(value: Float::INFINITY)
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
        backtrace_line  = record_exception(99) { BasicObject.new.instance_eval { not_a_local_or_meth } }
        backtrace_frame = 0
        backtrace_frame += 1 if defined? Rubinius # their method missing goes into the kernel
        assert_exception consumer.call,
                         recorded_line_no:   99,
                         class_name_matcher: /^NameError$/,
                         message_matcher:    /\bnot_a_local_or_meth\b/,
                         backtrace_index:    backtrace_frame,
                         backtrace_line:     backtrace_line,
                         backtrace_filename: __FILE__
      end

      context 'when the exception is a SystemExit' do
        it 'returns the status and does not record the exception' do
          exception = nil
          begin exit 22
          rescue SystemExit
            exception = $!
          end

          exitstatus = producer.record_exception(1, exception)
          expect(exitstatus).to eq 22
          finish!
          expect(consumer.each.find { |e| e.kind_of? Events::Exception }).to eq nil
        end
      end

      it 'works with objects whose boolean inquiries have been messed with (#131)' do
        exception = begin; raise; rescue; $!; end
        bad_bool  = Object.new
        def bad_bool.!(*) raise; end
        producer.record_exception bad_bool, exception # should not explode
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
          expect(consumer.call).to eq Events::SiBVersion.new(value: "1.2.3")
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
        expect(consumer.call).to eq Events::RubyVersion.new(value: 'o.m.g.')
      end
    end

    describe 'record_filename' do
      it 'sets the filename' do
        producer.record_filename 'this-iz-mah-file.rb'
        expect(producer.filename).to eq 'this-iz-mah-file.rb'
      end
      it 'emits the filename' do
        producer.record_filename 'this-iz-mah-file.rb'
        expect(consumer.call).to eq Events::Filename.new(value: 'this-iz-mah-file.rb')
      end
    end

    describe 'stdout' do
      it 'is emitted along with the events from the event stream' do
        stdout_producer.puts "this is the stdout¡"
        expect(consumer.call).to eq Events::Stdout.new(value: "this is the stdout¡\n")
      end
      specify 'each line is emitted as an event' do
        stdout_producer.puts "first"
        stdout_producer.puts "second\nthird"
        expect(consumer.call).to eq Events::Stdout.new(value: "first\n")
        expect(consumer.call).to eq Events::Stdout.new(value: "second\n")
        expect(consumer.call).to eq Events::Stdout.new(value: "third\n")
      end
    end

    describe 'stderr' do
      it 'is emitted along with the events from the event stream' do
        stderr_producer.puts "this is the stderr¡"
        expect(consumer.call).to eq Events::Stderr.new(value: "this is the stderr¡\n")
      end
      specify 'each line is emitted as an event' do
        stderr_producer.puts "first"
        stderr_producer.puts "second\nthird"
        expect(consumer.call).to eq Events::Stderr.new(value: "first\n")
        expect(consumer.call).to eq Events::Stderr.new(value: "second\n")
        expect(consumer.call).to eq Events::Stderr.new(value: "third\n")
      end
    end

    describe 'record_exec' do
      it 'records the event and the inspection of the args that were given to exec' do
        producer.record_exec(["ls", "-l"])
        expect(consumer.call).to eq Events::Exec.new(args: '["ls", "-l"]')
      end
    end

    describe 'record_num_lines' do
      it 'interprets numbers' do
        producer.record_num_lines 21
        expect(consumer.call).to eq Events::NumLines.new(value: 21)
      end
    end

    describe 'finish!' do
      it 'stops the producer from producing' do
        read, write = IO.pipe
        producer = SeeingIsBelieving::EventStream::Producer.new write
        producer.finish!
        producer.record_filename("zomg")
        write.close
        expect(read.gets).to eq nil
      end
    end

    describe 'final events' do
      it 'emits a StdoutClosed event when consumer side of stdout closes' do
        stdout_consumer.close
        expect(consumer.call).to eq Events::StdoutClosed.new(side: :consumer)
      end
      it 'emits a StdoutClosed event when producer side of stdout closes' do
        stdout_producer.close
        expect(consumer.call).to eq Events::StdoutClosed.new(side: :producer)
      end

      it 'emits a StderrClosed event when consumer side of stderr closes' do
        stderr_consumer.close
        expect(consumer.call).to eq Events::StderrClosed.new(side: :consumer)
      end
      it 'emits a StderrClosed event when producer side of stderr closes' do
        stderr_producer.close
        expect(consumer.call).to eq Events::StderrClosed.new(side: :producer)
      end

      it 'emits a EventStreamClosed event when consumer side of event_stream closes' do
        eventstream_consumer.close
        expect(consumer.call).to eq Events::EventStreamClosed.new(side: :consumer)
      end
      it 'emits a EventStreamClosed event when producer side of event_stream closes' do
        eventstream_producer.close
        expect(consumer.call).to eq Events::EventStreamClosed.new(side: :producer)
      end

      it 'emits a Exitstatus event on process_exitstatus' do
        consumer.process_exitstatus 92
        expect(consumer.call).to eq Events::Exitstatus.new(value: 92)
      end

      it 'translates missing statusses to 1 (eg this happens on my machine when the program segfaults, see #100)' do
        # I'm not totally sure this is the right thing for it to do, but a segfault is the only way
        # I know of to invoke this situation, and a segfault is printable, so until I get some info
        # that proves this is the wrong thing to do, we're just going to give it a normal exit status
        # since that's the easiest thing to do, and it's more correct in this one case.
        consumer.process_exitstatus nil
        expect(consumer.call).to eq Events::Exitstatus.new(value: 1)
      end

      it 'emits a Finished event when all streams are closed and it has an exit status' do
        consumer.process_exitstatus 1
        close_streams eventstream_producer, stdout_producer, stderr_producer
        expect(consumer.each.to_a.last).to eq Events::Finished.new
      end

      it 'emits a Timeout event on process_timeout' do
        consumer.process_timeout 1.23
        expect(consumer.call).to eq Events::Timeout.new(seconds:1.23)
      end

      it 'emits a Finished event when all streams are closed and it has a timeout' do
        consumer.process_timeout 1
        close_streams eventstream_producer, stdout_producer, stderr_producer
        expect(consumer.each.to_a.last).to eq Events::Finished.new
      end
    end


    describe Events do
      specify 'Event raises an error if .event_name was not overridden' do
        expect { Event.event_name }.to raise_error NotImplementedError
      end
      specify 'all events have a reasonable event name' do
        pairs = [
          [Events::Stdout           , :stdout],
          [Events::Stderr           , :stderr],
          [Events::MaxLineCaptures  , :max_line_captures],
          [Events::Filename         , :filename],
          [Events::NumLines         , :num_lines],
          [Events::SiBVersion       , :sib_version],
          [Events::RubyVersion      , :ruby_version],
          [Events::Exitstatus       , :exitstatus],
          [Events::Timeout          , :timeout],
          [Events::Exec             , :exec],
          [Events::ResultsTruncated , :results_truncated],
          [Events::LineResult       , :line_result],
          [Events::Exception        , :exception],
          [Events::StdoutClosed     , :stdout_closed],
          [Events::StderrClosed     , :stderr_closed],
          [Events::EventStreamClosed, :event_stream_closed],
          [Events::Finished         , :finished],
        ]
        pairs.each { |klass, name| expect(klass.event_name).to eq name }

        events_we_tested = pairs.map(&:first).flatten
        event_classes = Events.constants.map { |name| Events.const_get name }
        expect(event_classes - events_we_tested).to eq []
      end
      specify 'their event_name and attributes are included in their as_json' do
        expect(Events::Stdout.new(value: "abc").as_json).to eq [:stdout, {value: "abc"}]
      end
      specify 'MaxLineCaptures#as_json includes is_infinity, and sets value to -1 in this case' do
        expect(Events::MaxLineCaptures.new(value: Float::INFINITY).as_json).to eq [:max_line_captures, {value: -1, is_infinity: true}]
        expect(Events::MaxLineCaptures.new(value: 123).as_json).to eq [:max_line_captures, {value: 123, is_infinity: false}]
      end
    end

    require 'seeing_is_believing/event_stream/handlers/stream_json_events'
    describe Handlers::StreamJsonEvents do
      it 'writes each event\'s json representation to the stream' do
        stream  = ""
        handler = described_class.new stream

        handler.call Events::Stdout.new(value: "abc")
        expect(stream).to eq %'["stdout",{"value":"abc"}]\n'

        handler.call Events::Finished.new
        expect(stream).to eq %'["stdout",{"value":"abc"}]\n'+
                             %'["finished",{}]\n'
      end

      it 'calls flush after each event, when the stream responds to it' do
        stream = object_spy $stdout
        flushcount = 0
        allow(stream).to receive(:flush) { flushcount += 1 }

        handler = described_class.new stream
        expect(flushcount).to eq 0

        handler.call Events::Stdout.new(value: "abc")
        expect(flushcount).to eq 1

        handler.call Events::Finished.new
        expect(flushcount).to eq 2
      end
    end

    describe Handlers::Debug do
      let(:stream)          { "" }
      let(:events_seen)     { [] }
      let(:debugger)        { SeeingIsBelieving::Debugger.new stream: stream }
      let(:parent_observer) { lambda { |event| events_seen << event } }
      let(:debug_handler)   { described_class.new(debugger, parent_observer) }

      it 'passes events through to the parent observer' do
        event = Events::Stdout.new(value: "zomg")
        debug_handler.call(event)
        expect(events_seen).to eq [event]
      end

      it 'generally prints things, prettily, wide and short' do
        [ Events::Stdout.new(value: "short"),
          Events::Stdout.new(value: "long"*1000),
          Events::Exec.new(args: ["a", "b", "c"]),
          Events::StdoutClosed.new(side: :consumer),
          Events::Exception.new(line_number: 100,
                                class_name:  "SomethingException",
                                message:     "The things, they blew up!",
                                backtrace:   ["a"*10,"b"*2000]),
          Events::Finished.new,
        ].each { |event| debug_handler.call event }

        expect(stream).to match /^Stdout\b/   # the events al made it
        expect(stream).to match /^Exec\b/
        expect(stream).to match /^StdoutClosed\b/
        expect(stream).to match /^Exception\b/
        expect(stream).to match /^Finished\b/
        expect(stream).to match /^\| - a+/    # a backtrace in there
        expect(stream).to match /\.{3}$/      # truncation indication
        stream.each_line do |line|
          expect(line.length).to be <= 151    # long lines got truncated (151 b/c newline is counted)
        end
      end
    end

    # most tests are just in the sense that fkn everything uses it all over the place
    # but they use the valid cases, so this is just hitting the invalid one
    require 'seeing_is_believing/event_stream/handlers/update_result'
    describe Handlers::UpdateResult do
      it 'raises an error if it sees an event it doesn\'t know' do
        expect { described_class.new(double :result).call("unknown event") }
          .to raise_error /unknown event/
      end
    end
  end
end
