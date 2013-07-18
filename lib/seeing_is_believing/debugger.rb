class SeeingIsBelieving
  class Debugger

    CONTEXT_COLOUR = "\e[37;44m"
    RESET_COLOUR   = "\e[0m"

    def initialize(options={})
      @contexts = Hash.new { |h, k| h[k] = [] }
      @enabled  = options.fetch :enabled, true
      @coloured = options.fetch :colour,  false
    end

    def enabled?
      @enabled
    end

    def coloured?
      @coloured
    end

    def context(name, &block)
      @contexts[name] << block.call if enabled?
      self
    end

    def to_s
      @contexts.map { |name, values|
        string = ""
        string << CONTEXT_COLOUR if coloured?
        string << "#{name}:"
        string << RESET_COLOUR if coloured?
        string << "\n#{values.join "\n"}\n"
      }.join("\n")
    end
  end
end
