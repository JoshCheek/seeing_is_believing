class SeeingIsBelieving
  class Binary
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
            when '-h', '--help'          then options[:help] = self.class.help_screen
            when '-l', '--start-line'    then extract_positive_int_for :start_line,    arg
            when '-L', '--end-line'      then extract_positive_int_for :end_line,      arg
            when '-d', '--line-length'   then extract_positive_int_for :line_length,   arg
            when '-D', '--result-length' then extract_positive_int_for :result_length, arg
            when '-r', '--require'       then next_arg("#{arg} expected a filename but did not see one") { |filename| options[:require] << filename }
            when '-I', '--load-path'     then next_arg("#{arg} expected a directory but did not see one") { |dir| options[:load_path] << dir }
            when '-e', '--program'       then next_arg("#{arg} expects a program as the following argument") { |program| options[:program] = program }
            when /^-/                    then options[:errors] << "Unknown option: #{arg.inspect}" # unknown flags
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
        elsif filenames.any? && options[:program]
          options[:errors] << "You passed the program in an argument, but have also specified the filename #{filenames.first}"
        end

        if options[:end_line] < options[:start_line]
          options[:start_line], options[:end_line] = options[:end_line], options[:start_line]
        end
      end

      def options
        @options ||= {
          program:       nil,
          filename:      nil,
          errors:        [],
          start_line:    1,
          line_length:   Float::INFINITY,
          end_line:      Float::INFINITY,
          result_length: Float::INFINITY,
          require:       [],
          load_path:     [],
        }
      end

      def next_arg(error_message, &success_block)
        arg = args.shift
        arg ? success_block.call(arg) : (options[:errors] << error_message)
      end

      def extract_positive_int_for(key, flag)
        string = args.shift
        int    = string.to_i
        if int.to_s == string && 0 < int
          options[key] = int
        else
          options[:errors] << "#{flag} expects a positive integer argument"
        end
      end
    end

    def ArgParser.help_screen
<<HELP_SCREEN
Usage: #{$0} [options] [filename]

  #{$0} is a program and library that will evaluate a Ruby file and capture/display the results.

  If no filename is provided, the binary will read the program from standard input.

  -l, --start-line    # line number to begin showing results on
  -L, --end-line      # line number to stop showing results on
  -d, --line-length   # max length of the entire line (only truncates results, not source lines)
  -D, --result-length # max length of the portion after the "# => "
  -r, --require       # additional files to be required before running the program
  -e, --program       # Pass the program to execute as an argument
  -h, --help          # this help screen
HELP_SCREEN
    end
  end
end
