require 'seeing_is_believing/debugger'
require 'seeing_is_believing/strict_hash'
require 'seeing_is_believing/binary/help_screen'

require 'seeing_is_believing/binary/align_file'
require 'seeing_is_believing/binary/align_line'
require 'seeing_is_believing/binary/align_chunk'

require 'seeing_is_believing/binary/annotate_every_line'
require 'seeing_is_believing/binary/annotate_xmpfilter_style'


class SeeingIsBelieving
  module Binary
    class Config < StrictHash

      # TODO: Should probably object-ify these
      class Markers < StrictHash
        attributes value:     '# => '.freeze,
                   exception: '# ~> '.freeze,
                   stdout:    '# >> '.freeze,
                   stderr:    '# !> '.freeze
      end

      class MarkerRegexes < StrictHash
        def self.to_regex(string)
          flag_to_bit = {'i' => 0b001, 'x' => 0b010, 'm' => 0b100}
          string =~ %r{\A/(.*)/([mxi]*)\Z}
          Regexp.new ($1||string),
                     ($2||"").each_char.inject(0) { |bits, flag| bits|flag_to_bit[flag] }
        end

        attributes value:     to_regex('^#\s*=>\s*'),
                   exception: to_regex('^#\s*~>\s*'),
                   stdout:    to_regex('^#\s*>>\s*'),
                   stderr:    to_regex('^#\s*!>\s*')
      end

      # passed to SeeingIsBelieving.new
      # TODO: make program body an arg like these ones (ie all args are keyword)
      # TODO: Move LibOptions into library
      class LibOptions < StrictHash
        attribute(:filename)          { nil }
        attribute(:encoding)          { nil }
        attribute(:stdin)             { "" }
        attribute(:require)           { ['seeing_is_believing/the_matrix'] } # TODO: should rename to requires ?
        attribute(:load_path)         { [File.expand_path('../../..', __FILE__)] } # TODO: should rename to load_path_dirs ?
        attribute(:timeout_seconds)   { 0 }
        attribute(:debugger)          { Debugger.new stream: nil } # TODO: Debugger.null
        attribute(:max_line_captures) { Float::INFINITY }
        require 'seeing_is_believing/annotate'
        attribute(:annotate)          { Annotate }
      end

      # passed to annotator.call
      # todo move AnnotatorOptions to uhm, annotator or something
      class AnnotatorOptions < StrictHash
        attribute(:alignment_strategy) { AlignChunk }
        attribute(:debugger)           { Debugger.new stream: nil } # TODO: Debugger.null
        attribute(:markers)            { Markers.new }
        attribute(:marker_regexes)     { MarkerRegexes.new }
        attribute(:max_line_length)    { Float::INFINITY }
        attribute(:max_result_length)  { Float::INFINITY }
      end

      predicate(:print_version)       { false }
      predicate(:print_cleaned)       { false }
      predicate(:print_help)          { false }
      predicate(:print_extended_help) { false }
      predicate(:result_as_json)      { false }
      predicate(:inherit_exit_status) { false }
      predicate(:debug)               { false }

      attribute(:body)                { nil }
      attribute(:filename)            { nil }
      attribute(:errors)              { [] }
      attribute(:deprecations)        { [] }
      attribute(:timeout_seconds)     { 0 }
      attribute(:annotator)           { AnnotateEveryLine }
      attribute(:debugger)            { Debugger.new stream: nil } # TODO: Debugger.null
      attribute(:markers)             { Markers.new }
      attribute(:marker_regexes)      { MarkerRegexes.new }
      attribute(:help_screen)         { Binary.help_screen false, Markers.new }
      attribute(:lib_options)         { LibOptions.new }
      attribute(:annotator_options)   { AnnotatorOptions.new }

      def self.from_args(args, stdin, debug_stream)
        new { |opts| opts.parse_args(args, debug_stream) }
          .finalize(stdin, File)
      end


      # TODO: allow debugger to take a filename

      # TODO: --cd dir | --cd :file:
      #   when given a dir, cd to that dir before executing the code
      #   when not given a dir, cd to the dir of the file being executed before executing it

      # TODO: --only-show-lines
      #   Output only on specified lines (doesn't change stdout/stderr/exceptions)

      # TODO: --alignment-strategy n-or-line / n-or-chunk / n-or-file (help-file should prob just link to cuke examples)
      # add default to number of captures (1000), require user to explicitly set it to infinity
      def parse_args(args, debug_stream)
        as        = nil
        filenames = []
        args      = args.dup

        extract_positive_int_for = lambda do |flagname, &on_success|
          string = args.shift
          int    = string.to_i
          if int.to_s == string && 0 < int
            on_success.call int
          else
            self.errors << "#{flag} expects a positive integer argument"
          end
          string
        end

        extract_non_negative_float_for = lambda do |flagname, &on_success|
          begin
            string = args.shift
            float  = Float string
            raise if float < 0
            on_success.call float
            string
          rescue
            flags[:errors] << "#{flagname} expects a positive float or integer argument"
          end
        end

        deprecated_arg = Class.new StrictHash do
          attributes :args, :explanation
          def to_s
            "Deprecated: `#{args.join ' '}` #{explanation}"
          end
        end

        saw_deprecated = lambda do |explanation, *args|
          self.deprecations << deprecated_arg.new(explanation: explanation, args: args)
        end

        # TODO: next_arg(error_message, success: callback, failure: callback)
        next_arg = lambda do |error_message, &on_success|
          arg = args.shift
          arg ? on_success.call(arg) :
                self.errors << error_message
          arg
        end

        until args.empty?
          case (arg = args.shift)
          when '-h',  '--help'                  then self.print_help          = true
                                                     Binary.help_screen(false, markers)
          when '-h+', '--help+'                 then self.print_help          = true
                                                     self.help_screen         = Binary.help_screen(true, markers)
          when '-c',  '--clean'                 then self.print_cleaned       = true
          when '-v',  '--version'               then self.print_version       = true
          when '-x',  '--xmpfilter-style'       then self.annotator           = AnnotateXmpfilterStyle
          when '-i',  '--inherit-exit-status'   then self.inherit_exit_status = true
          when '-j',  '--json'                  then self.result_as_json      = true
          when '-g',  '--debug'
            self.debug                      = true
            self.debugger                   = Debugger.new stream: debug_stream, colour: true
            self.lib_options.debugger       = debugger
            self.annotator_options.debugger = debugger

          when '-d',  '--line-length'
            extract_positive_int_for.call arg do |n|
              self.annotator_options.max_line_length = n
            end

          when '-D', '--result-length'
            extract_positive_int_for.call arg do |n|
              self.annotator_options.max_result_length = n
            end

          when '-n', '--max-line-captures', '--number-of-captures'
            extracted = extract_positive_int_for.call arg do |n|
              self.lib_options.max_line_captures = n
            end
            '--number-of-captures' == arg && saw_deprecated.call("use --max-line-captures instead", arg, extracted)

          when '-t', '--timeout-seconds', '--timeout'
            extracted = extract_non_negative_float_for.call arg do |n|
              self.timeout_seconds             = n
              self.lib_options.timeout_seconds = n
            end
            '--timeout' == arg  && saw_deprecated.call("use --timeout-seconds instead", arg, extracted)

          when '-r', '--require'
            next_arg.call "#{arg} expected a filename as the following argument but did not see one" do |filename|
              self.lib_options.require << filename
            end

          when '-I', '--load-path'
            next_arg.call "#{arg} expected a directory as the following argument but did not see one" do |dir|
              self.lib_options.load_path << dir
            end

          when '-e', '--program'
            next_arg.call "#{arg} expected a program as the following argument but did not see one" do |program|
              self.body = program
            end

          when '-a', '--as'
            next_arg.call "#{arg} expected a filename as the following argument but did not see one"  do |filename|
              as = filename
            end

          when '-s', '--alignment-strategy'
            strategies = {'file' => AlignFile, 'chunk' => AlignChunk, 'line' => AlignLine}
            strategy_names = strategies.keys.join(', ')
            next_arg.call "#{arg} expected an alignment strategy as the following argument but did not see one (choose from: #{strategy_names})" do |name|
              if strategies[name]
                self.annotator_options.alignment_strategy = strategies[name]
              else
                errors << "#{arg} does not know #{name}, only knows: #{strategy_names}"
              end
            end

          when /\A-K(.+)/
            self.lib_options.encoding = $1

          when '-K', '--encoding'
            next_arg.call "#{arg} expects an encoding, see `man ruby` for possibile values" do |encoding|
              self.lib_options.encoding = encoding
            end

          when '--shebang'
            executable = args.shift
            if executable
              saw_deprecated.call "SiB now uses the Ruby it was invoked with", arg, [executable]
            else
              errors << "#{arg} expected an arg: path to a ruby executable"
              saw_deprecated.call "SiB now uses the Ruby it was invoked with", arg, []
            end

          when /^(-.|--.*)$/
            self.errors << "Unknown option: #{arg.inspect}"

          when /^-[^-]/
            shortflags = arg[1..-1].chars.to_a
            plusidx    = shortflags.index('+') || 0
            if 0 < plusidx
              shortflags[plusidx-1] << '+'
              shortflags.delete_at plusidx
            end
            args.unshift *shortflags.map { |flag| "-#{flag}" }

          else
            filenames << arg
          end
        end

        self.filename = filenames.first
        filenames.size > 1 &&
          errors << "Can only have one filename, but had: #{filenames.map(&:inspect).join ', '}"

        self.lib_options.filename = as || filename
        self.lib_options.annotate = annotator.expression_wrapper(markers, marker_regexes) # TODO: rename to wrap_expressions
        self.lib_options.debugger = debugger

        self.annotator_options.debugger       = debugger
        self.annotator_options.markers        = markers
        self.annotator_options.marker_regexes = marker_regexes

        self
      end

      def finalize(stdin, file_class)
        if filename && body
          errors << "Cannot give a program body and a filename to get the program body from."
        elsif filename && file_class.exist?(filename)
          self.lib_options.stdin = stdin
          self.body = file_class.read filename
        elsif filename
          errors << "#{filename} does not exist!"
        elsif body
          self.lib_options.stdin = stdin
        else
          self.body = stdin.read
        end
        self
      end

    end
  end
end
