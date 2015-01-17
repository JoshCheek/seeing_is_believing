class SeeingIsBelieving
  module EventStream
    module Handlers
      class Debug
        def initialize(debugger, handler)
          @debugger   = debugger
          @handler    = handler
          @seen       = ""
          @line_width = 150 # debugger is basically for me, so giving it a nice wide width
          @name_width = 20
          @attr_width = @line_width - @name_width
        end

        def call(event)
          observe event
          finish if event.kind_of? Events::Finished
          @handler.call event
        end

        private

        attr_reader :debugger, :handler

        def finish
          @debugger.context("EVENTS:") { @seen }
        end

        def observe(event)
          name  = event.class.name.split("::").last
          lines = event.to_h
                       .map { |attribute, value|
                          case attribute
                          when :side      then "#{attribute}: #{value}"
                          when :value     then value.to_s.chomp
                          when :backtrace then indented = value.map { |v| "- #{v}" }
                                               ["backtrace:", *indented]
                          else "#{attribute}: #{value.inspect}"
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
end
