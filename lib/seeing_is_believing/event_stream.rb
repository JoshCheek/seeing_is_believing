class SeeingIsBelieving
  # At the binary level, streaming will have to be opted into, b/c you'd need something on the other side that could display it
  # TODO: we'll use eval for now, later just escape \ns
  module EventStream
    module Event
      LineResult       = Struct.new(:type, :line_number, :inspected)
      UnrecordedResult = Struct.new(:type, :line_number)
      Exception        = Struct.new(:line_number, :class_name, :message, :backtrace) do
        def initialize
          super -1, '', '', []
        end
      end
    end

    class Consumer
      def initialize(readstream)
        @readstream = readstream
      end

      def call(n=1)
        return event_for @readstream.gets if n == 1
        n.times.map { event_for @readstream.gets }
      end

      private

      def extract_token(line)
        event_name = line[/[^ ]*/]
        line.sub! /[^ ]*\s*/, ''
        event_name
      end

      # for a consideration of many different ways of doing this, see 5633064
      def extract_string(line)
        Marshal.load extract_token(line).unpack('m0').first
      end

      def event_for(line)
        line.chomp!
        event_name = extract_token(line)
        case event_name
        when 'result'
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          inspected   = extract_string(line)
          Event::LineResult.new(type, line_number, inspected)
        when 'maxed_result'
          line_number = extract_token(line).to_i
          type        = extract_token(line).intern
          Event::UnrecordedResult.new(type, line_number)
        when 'exception'
          case extract_token(line).intern
          when :begin
            @exception = Event::Exception.new
            call
          when :line_number
            @exception.line_number = extract_token(line).to_i
            call
          when :class_name
            @exception.class_name = extract_string(line)
            call
          when :message
            @exception.message = extract_string(line)
            call
          when :backtrace
            @exception.backtrace << extract_string(line)
            call
          when :end
            @exception
          end
        else
          raise "IDK what #{event_name.inspect} is!"
        end
      end
    end

    class Publisher
      attr_accessor :exitstatus, :bug_in_sib, :max_line_captures  # => nil
      attr_accessor :resultstream                                 # => nil
      attr_accessor :recorded_results                             # => nil

      def initialize(resultstream)
        self.resultstream      = resultstream                                          # => #<StringIO:0x007f974404c788>
        self.exitstatus        = 0                                                     # => 0
        self.bug_in_sib        = false                                                 # => false
        self.max_line_captures = Float::INFINITY                                       # => Infinity
        self.recorded_results  = Hash.new { |h, line_num| h[line_num] = Hash.new(0) }  # => {}
      end

      # TODO: delete?
      def bug_in_sib=(bool)
        @bug_in_sib = !!bool  # => false
      end

      # for a consideration of many different ways of doing this, see 5633064
      def to_string_token(string)
        [Marshal.dump(string.to_s)].pack('m0')
      end

      # TODO: can record basic object and that shit
      # TODO: only records inspect once
      # TODO: Check whatever else result is currently doing
      def record_result(type, line_number, value)
        count = recorded_results[line_number][type]
        recorded_results[line_number][type] = count + 1
        if count < max_line_captures
          resultstream << "result #{line_number} #{type} #{to_string_token value.inspect}\n"
        elsif count == max_line_captures
          resultstream << "maxed_result #{line_number} #{type}\n"
        end
        value
      end

      def record_exception(line_number, exception)
        resultstream << "exception begin\n"
        resultstream << "exception line_number #{line_number}\n"                        # => #<StringIO:0x007f974404c788>
        resultstream << "exception class_name  #{to_string_token exception.class.name}\n"  # => #<StringIO:0x007f974404c788>
        resultstream << "exception message     #{to_string_token exception.message}\n"     # => #<StringIO:0x007f974404c788>
        exception.backtrace.each do |line|                                              # => ["/var/folders/7g/mbft22555w3_2nqs_h1kbglw0000gn/T/seeing_is_believing_temp_dir20140913-72389-i6ovhi/program.rb:66:in `<main>'"]
          resultstream << "exception backtrace #{to_string_token line}\n"                       # => #<StringIO:0x007f974404c788>
        end                                                                             # => ["/var/folders/7g/mbft22555w3_2nqs_h1kbglw0000gn/T/seeing_is_believing_temp_dir20140913-72389-i6ovhi/program.rb:66:in `<main>'"]
        resultstream << "exception end\n"
      end

      # TODO with a mutex, we could also write this dynamically!
      def record_stdout(stdout)
        resultstream << "stdout #{stdout.inspect}\n"  # => #<StringIO:0x007f974404c788>
      end

      def record_stderr(stderr)
        resultstream << "stderr #{stderr.inspect}\n"  # => #<StringIO:0x007f974404c788>
      end

      def finalize
        resultstream << "bug_in_sib #{bug_in_sib}\n"                # => #<StringIO:0x007f974404c788>
        resultstream << "max_line_captures #{max_line_captures}\n"  # => #<StringIO:0x007f974404c788>
        resultstream << "exitstatus #{exitstatus}\n"                # => #<StringIO:0x007f974404c788>
      end
    end
  end
end
