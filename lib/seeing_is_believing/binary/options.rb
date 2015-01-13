# Debugger initialization
require 'seeing_is_believing/debugger'

# Alignment decision
require 'seeing_is_believing/binary/align_file'
require 'seeing_is_believing/binary/align_line'
require 'seeing_is_believing/binary/align_chunk'

# Evaluator decision
require 'seeing_is_believing/evaluate_by_moving_files'

# Annotator decision
require 'seeing_is_believing/binary/annotate_every_line'
require 'seeing_is_believing/binary/annotate_xmpfilter_style'

# Options data structure
require 'seeing_is_believing/strict_hash'


class SeeingIsBelieving
  module Binary
    class Options < StrictHash
      # TODO: this goes somewhere, but not sure its here. If we do a markers object, then probably there
      def self.to_regex(string)
        flag_to_bit = {'i' => 0b001, 'x' => 0b010, 'm' => 0b100}
        string =~ %r{\A/(.*)/([mxi]*)\Z}
        Regexp.new ($1||string),
                   ($2||"").each_char.inject(0) { |bits, flag| bits|flag_to_bit[flag] }
      end

      predicates :print_version, :inherit_exit_status, :result_as_json,
                 :print_help, :print_cleaned, :file_is_on_stdin

      attributes :annotator, :help_screen, :debugger, :markers,
                 :marker_regexes, :timeout_seconds, :filename,
                 :body, :annotator_options, :lib_options, :errors,
                 :deprecations

      def self.init(flags, stdin, stdout, stderr)
        new { |opts| opts.init_from_flags flags, stdin, stdout, stderr }
      end


      def init_from_flags(flags, stdin, stdout, stderr)
        # Some simple attributes
        self[:deprecations]    = flags[:deprecated_args]
        self[:errors]          = flags[:errors]
        self[:markers]         = flags[:markers] # TODO: Should probably object-ify these
        self[:marker_regexes]  = flags[:marker_regexes].each_with_object({}) { |(k, v), rs| rs[k] = self.class.to_regex v }
        self[:timeout_seconds] = flags[:timeout_seconds]
        self[:filename]        = flags[:filename]

        # Most predicates
        self[:print_version]       = flags[:print_version]
        self[:inherit_exit_status] = flags[:inherit_exit_status]
        self[:result_as_json]      = flags[:result_as_json]
        self[:print_help]          = !!flags[:help]
        self[:print_cleaned]       = flags[:clean]
        self[:file_is_on_stdin]    = (!filename && !flags[:program_from_args])

        # Polymorphism, y'all!
        # TODO: rename xmpfilter_style to something more about behaviour than inspiration ie AnnotateMarkedLines
        self[:annotator]   = (flags[:xmpfilter_style] ? AnnotateXmpfilterStyle    : AnnotateEveryLine)
        self[:help_screen] = flags[:help] == 'help'   ? flags[:short_help_screen] : flags[:long_help_screen]
        # TODO: allow debugger to take a stream
        self[:debugger]    = flags[:debug]            ? Debugger.new(stream: stderr, colour: true) : Debugger.new(stream: nil)

        # The lib's options (passed to SeeingIsBelieving.new)
        self[:lib_options] = {
          filename:          (flags[:as] || filename),
          stdin:             (file_is_on_stdin? ? '' : stdin),
          require:           (['seeing_is_believing/the_matrix'] + flags[:require]), # TODO: rename requires: files_to_require, or :requires or maybe :to_require
          load_path:         ([File.expand_path('../../..', __FILE__)] + flags[:load_path]),
          encoding:          flags[:encoding],
          timeout_seconds:   timeout_seconds,
          debugger:          debugger,
          max_line_captures: flags[:max_line_captures],
          annotate:          annotator.expression_wrapper(markers, marker_regexes), # TODO: rename to wrap_expressions
        }

        # The annotator's options (passed to annotator.call)
        self[:annotator_options] = {
          alignment_strategy: extract_alignment_strategy(flags[:alignment_strategy], errors),
          debugger:           debugger,
          markers:            markers,
          marker_regexes:     marker_regexes,
          max_line_length:    flags[:max_line_length],
          max_result_length:  flags[:max_result_length],
        }

        # Some error checking
        if 1 < flags[:filenames].size
          errors << "Can only have one filename, but had: #{flags[:filenames].map(&:inspect).join ', '}"
        elsif filename && flags[:program_from_args]
          errors << "You passed the program in an argument, but have also specified the filename #{filename.inspect}"
        end

        # Body
        errors << "#{filename} does not exist!" if filename && !File.exist?(filename)
        self[:body] = ((print_version? || print_help? || errors.any?) && "") ||
                      flags[:program_from_args]                              ||
                      (file_is_on_stdin? && stdin.read)                      ||
                      File.read(filename)
      end


      # TODO: Options inspects itself if debugger is set to true
      def inspect
        inspected = "#<#{self.class.name.inspect}\n"
        inspected << "  --PREDICATES--\n"
        # predicates.each do |predicate, value|
        #   inspected << inspect_line(sprintf "    %-25s %p", predicate.to_s+"?", value)
        # end
        inspected << "  --ATTRIBUTES--\n"
        each do |predicate, value|
          inspected << inspect_line(sprintf "    %-20s %p", predicate.to_s, value)
        end
        inspected << ">"
        inspected
      end



      private

      def inspect_line(line)
        if line.size < 78
          line << "\n"
        else
          line[0, 75] << "...\n"
        end
      end

      def extract_alignment_strategy(strategy_name, errors)
        strategies = {'file' => AlignFile, 'chunk' => AlignChunk, 'line' => AlignLine}
        if strategies[strategy_name]
          strategies[strategy_name]
        elsif strategy_name
          errors << "alignment-strategy does not know #{strategy_name}, only knows: #{strategies.keys.join(', ')}"
        else
          errors << "alignment-strategy expected an alignment strategy as the following argument but did not see one"
        end
      end
    end
  end
end
