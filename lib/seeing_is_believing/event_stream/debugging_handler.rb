class SeeingIsBelieving
  module EventStream
    class DebuggingHandler
      def initialize(debugger, handler)
        @debugger   = debugger
        @handler    = handler
        @seen       = ""
        @enabled    = debugger.enabled?
        @line_width = 150 # debugger is basically for me, so giving it a nice wide width
        @name_width = 20
        @attr_width = @line_width - @name_width
      end

      def to_proc
        return @handler.to_proc unless @enabled # no-op when there's no point
        lambda do |event|
          observe event
          finish if event.kind_of? Events::Finished
          @handler.call event
        end
      end

      private

      def finish
        @debugger.context("EVENTS") { @seen }
      end

      def observe(event)
        name = event.class.name.split("::").last
        lines = event.to_h
                     .map { |attribute, value|
                       if attribute == :value
                         value.to_s.chomp
                       elsif attribute == :side
                         "#{attribute}: #{value}"
                       elsif attribute == :backtrace
                         indented = value.map { |v| "- #{v}" }
                         ["backtrace:", *indented]
                       else
                         "#{attribute}: #{value.inspect}"
                       end
                     }
                     .flatten
        joined = lines.join ", "
        if joined.size < @attr_width
          @seen << sprintf("%-#{@name_width}s%s\n", name, joined)
        elsif lines.size == 1
          @seen << sprintf("%-#{@name_width}s%s...\n", name, lines.first[0...@attr_width-3])
        else
          @seen << "#{name}\n"
          lines.each { |line|
            line = line[0...@line_width-5] << "..." if @line_width < line.length + 2
            @seen << sprintf("| %s\n", line)
          }
        end
      end
    end
  end
end
