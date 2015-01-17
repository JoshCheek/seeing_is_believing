class SeeingIsBelieving
  class Debugger
    CONTEXT_COLOUR = "\e[37;44m" # background blue
    RESET_COLOUR   = "\e[0m"

    def initialize(options={})
      @coloured = options[:colour]
      @stream   = options[:stream]
    end

    Null = new stream: nil

    def coloured?
      @coloured
    end

    attr_reader :stream
    alias enabled? stream

    def context(name, &block)
      if enabled?
        stream << CONTEXT_COLOUR if coloured?
        stream << "#{name}:"
        stream << RESET_COLOUR   if coloured?
        stream << "\n"
        stream << block.call.to_s << "\n" if block
      end
      self
    end
  end

end
