class SeeingIsBelieving
  class ArgParser
    def self.parse(args)
      new(args).call
    end

    attr_accessor :args

    def initialize(args)
      self.args      = args
      self.filenames = []
    end

    def call
      @result ||= begin
        until args.empty?
          case (arg = args.shift)

          # help screen
          when '-h', '--help'
            options[:help] = self.class.help_screen

          # start line
          when '-l', '--start-line'
            start_line = args.shift
            i_start_line = start_line.to_i
            if i_start_line.to_s == start_line && !i_start_line.zero?
              options[:start_line] = start_line.to_i
            else
              options[:errors] << "#{arg} expects a positive integer argument"
            end

          # end line
          when '-L', '--end-line'
            end_line = args.shift
            if end_line.to_i.to_s == end_line
              options[:end_line] = end_line.to_i
            else
              options[:errors] << "#{arg} expect an integer argument"
            end

          # unknown flags
          when /^-/
            options[:errors] << "Unknown option: #{arg.inspect}"

          # filenames
          else
            filenames << arg
            options[:filename] = arg
          end
        end
        normalize_and_validate
        options
      end
    end

    private

    attr_accessor :filenames

    def normalize_and_validate
      if 1 < filenames.size
        options[:errors] << "Can only have one filename, but had: #{filenames.map(&:inspect).join ', '}"
      end

      if options[:end_line] < options[:start_line]
        options[:start_line], options[:end_line] = options[:end_line], options[:start_line]
      end
    end

    def options
      @options ||= {
        filename:     nil,
        errors:       [],
        start_line:   1,
        end_line:     Float::INFINITY,
      }
    end
  end

  def ArgParser.help_screen
<<HELP_SCREEN
Usage: #{$0} [options] [filename]

  #{$0} is a program and library that will evaluate a Ruby file and capture/display the results.

  If no filename is provided, the binary will read the program from standard input.

  -l, --start-line  # line number to begin showing results on
  -L, --end-line    # line number to stop showing results on
  -h, --help        # this help screen
HELP_SCREEN
  end
end
