require 'seeing_is_believing/debugger'                 # Sets the debugger
require 'seeing_is_believing/binary/align_file'        # Polymorphically decides which alignment strategy to use
require 'seeing_is_believing/binary/align_line'        # Polymorphically decides which alignment strategy to use
require 'seeing_is_believing/binary/align_chunk'       # Polymorphically decides which alignment strategy to use
require 'seeing_is_believing/evaluate_by_moving_files' # Default evaluator
require 'seeing_is_believing/evaluate_with_eval_in'    # Evaluator for safe mode

class SeeingIsBelieving
  module Binary
    class InterpretFlags
      # def self.attr_predicate(*names)
      #   names.each do |name|
      #     define_method("#{name}?") { predicates.fetch name }
      #   end
      # end

      # def self.attr_attribute(*names)
      #   names.each do |name|
      #     define_method(name) { fetch name }
      #   end
      # end

      # TODO: once it stabilizes a bit, use the above methods instead
      def method_missing(name, *)
        if name.to_s.end_with?(??)
          predicates.fetch(name.to_s[0...-1].intern) { |k|
            raise "NO PREDICATE #{k.inspect} IN #{predicates.keys.inspect}"
          }
        else
          attributes.fetch(name) { |k|
            raise "NO ATTRIBUTE #{k.inspect} IN #{attributes.keys.inspect}"
          }
        end
      end

      # TODO: Push everything to where it goes
      # so we don't have this giant clusterfuck of attributes

      # TODO: move everthing into attributes
      # and define all methods to use them?
      # if we do this, we can have a really nice inspect method
      attr_reader :errors

      def initialize(flags, stdin, stdout)
        @errors    = flags.fetch(:errors) # TODO add this to attributes?
        attributes[:annotator]    = (flags.fetch(:xmpfilter_style) ? AnnotateXmpfilterStyle : AnnotateEveryLine)

        attributes[:help_screen]  = flags.fetch(:help) == 'help' ? flags.fetch(:short_help_screen) : flags.fetch(:long_help_screen)
        attributes[:debugger]     = flags.fetch(:debug) ? Debugger.new(stream: stdout, colour: true) :
                                                          Debugger.new(stream: nil)
        attributes[:markers]      = flags.fetch(:markers) # TODO:Should probably object-ify these
        attributes[:timeout]      = flags.fetch(:timeout) # TODO: rename seconds_until_timeout
        attributes[:shebang]      = flags.fetch(:shebang)
        attributes[:filename]     = flags.fetch(:filename)

        filenames = flags.fetch(:filenames)
        if 1 < filenames.size
          errors << "Can only have one filename, but had: #{filenames.map(&:inspect).join ', '}"
        elsif filenames.any? && flags.fetch(:program_from_args)
          errors << "You passed the program in an argument, but have also specified the filename #{filenames.first.inspect}"
        end

        @predicates = {
          print_version:         flags.fetch(:version), # TODO: rename to show_version?
          inherit_exit_status:   flags.fetch(:inherit_exit_status),
          result_as_json:        flags.fetch(:result_as_json),
          print_help:            !!flags.fetch(:help),
          print_cleaned:         flags.fetch(:clean), # TODO: Better name on rhs
          provided_filename_dne: (filename && !File.exist?(filename)),
          file_is_on_stdin:      (!filename && !flags.fetch(:program_from_args))
        }

        attributes[:body] = ''
        attributes[:body] = ((print_version? || print_help?) && '') ||
                            flags.fetch(:program_from_args) ||
                            (file_is_on_stdin? && stdin.read) ||
                            (File.read filename unless provided_filename_dne?)

        attributes[:prepared_body] = body && annotator.prepare_body(body, markers)

        attributes[:lib_options] = {
          evaluate_with:      (flags.fetch(:safe) ? EvaluateWithEvalIn : EvaluateByMovingFiles),
          filename:           (flags.fetch(:as) || filename),
          ruby_executable:    shebang,
          stdin:              (file_is_on_stdin? ? '' : stdin),
          require:            (['seeing_is_believing/the_matrix'] + flags.fetch(:require)), # TODO: rename requires: files_to_require
          load_path:          flags.fetch(:load_path),
          encoding:           flags.fetch(:encoding),
          timeout:            timeout,
          debugger:           debugger,
          number_of_captures: flags.fetch(:number_of_captures), # TODO: Rename to max_number_of_captures
          record_expressions: annotator.expression_wrapper(markers), # TODO: rename to wrap_expressions
        }

        attributes[:annotator_options] = {
          alignment_strategy: extract_alignment_strategy(flags.fetch(:alignment_strategy), errors),
          debugger:           debugger,
          markers:            markers,
          max_line_length:    flags.fetch(:max_line_length),
          max_result_length:  flags.fetch(:max_result_length),
        }
      end

      def fetch(*args)
        attributes.fetch(*args)
      end

      def [](key)
        attributes[key]
      end

      def print_errors?
        errors.any?
      end

      def merge(other)
        other.each do |k, v|
          attributes[k] = v # TODO: This is just until we group attributes by the places that need them
        end
      end

      private

      attr_accessor :predicates

      def timeout # TODO: ugh
        fetch(:timeout)
      end

      def attributes
        @attributes ||= {}
      end

      def extract_alignment_strategy(strategy_name, errors)
        strategies = {'file' => AlignFile, 'chunk' => AlignChunk, 'line' => AlignLine}
        if strategies[strategy_name]
          strategies[strategy_name]
        elsif name
          errors << "alignment-strategy does not know #{strategy_name}, only knows: #{strategies.keys.join(', ')}"
        else
          errors << "alignment-strategy expected an alignment strategy as the following argument but did not see one"
        end
      end
    end
  end
end
