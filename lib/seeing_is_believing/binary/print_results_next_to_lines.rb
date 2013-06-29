require 'seeing_is_believing/queue'
require 'seeing_is_believing/has_exception'
require 'seeing_is_believing/binary/line_formatter'

# I think there is a bug where with xmpfilter_style set,
# the exceptions won't be shown. But it's not totally clear
# how to show them with this option set, anyway.
# probably do what xmpfilter does and print them at the bottom
# of the file (probably do this regardless of whether xmpfilter_style
# is set)
#
# Would also be nice to support
#     1 + 1
#     # => 2
# style updates like xmpfilter does

class SeeingIsBelieving
  class Binary
    class PrintResultsNextToLines
      include HasException

         STDOUT_PREFIX = '# >>'
         STDERR_PREFIX = '# !>'
      EXCEPTION_PREFIX = '# ~>'
         RESULT_PREFIX = '# =>'

      def self.remove_previous_output_from(string)
        string.gsub(/\s+(#{EXCEPTION_PREFIX}|#{RESULT_PREFIX}).*?$/, '')
              .gsub(/(^\n)?(^#{STDOUT_PREFIX}[^\n]*\r?\n?)+/m,       '')
              .gsub(/(^\n)?(^#{STDERR_PREFIX}[^\n]*\r?\n?)+/m,       '')
      end


      def self.method_from_options(*args)
        define_method(args.first) { options.fetch *args }
      end

      method_from_options :filename, nil
      method_from_options :start_line
      method_from_options :end_line
      method_from_options :line_length,    Float::INFINITY
      method_from_options :result_length,  Float::INFINITY
      method_from_options :xmpfilter_style

      attr_accessor :file_result
      def initialize(body, options={})
        cleaned_body            = self.class.remove_previous_output_from body
        self.options            = options
        self.body               = (xmpfilter_style ? body : cleaned_body)
        self.file_result        = SeeingIsBelieving.call body(),
                                                         filename:  (options[:as] || options[:filename]),
                                                         require:   options[:require],
                                                         load_path: options[:load_path],
                                                         encoding:  options[:encoding],
                                                         stdin:     options[:stdin],
                                                         timeout:   options[:timeout]
        self.alignment_strategy = options[:alignment_strategy].new cleaned_body, start_line, end_line
      end

      def new_body
        @new_body ||= ''
      end

      def call
        @printed_program ||= begin
          # can we put the call to chomp into the line_queue initialization code?
          line_queue.until { |line, line_number| SyntaxAnalyzer.begins_data_segment?(line.chomp) }
                    .each  { |line, line_number| add_line line, line_number }
          add_stdout
          add_stderr
          add_remaining_lines
          new_body
        end
      end

      private

      attr_accessor :body, :options, :alignment_strategy

      def line_queue
        @line_queue ||= Queue.new &body.each_line.with_index(1).to_a.method(:shift)
      end

      # if we want to pull this into a strategy
      # we need to make available:
      #   file_result, start_line, end_line, alignment_strategy, line_length, result_length
      def add_line(line, line_number)
        should_record = should_record? line, line_number
        if should_record && xmpfilter_style && line.strip =~ /^# =>/
          new_body << xmpfilter_update(line, file_result[line_number - 1])
        elsif should_record && xmpfilter_style
          new_body << xmpfilter_update(line, file_result[line_number])
        elsif should_record
          new_body << format_line(line.chomp, line_number, file_result[line_number])
        else
          new_body << line
        end
      end

      def should_record?(line, line_number)
        (start_line <= line_number) &&
          (line_number <= end_line) &&
          (xmpfilter_style ? line =~ /# =>/ : # technically you could fuck this up with a line like "# =>", should later delegate to syntax analyzer
                             !SyntaxAnalyzer.ends_in_comment?(line))
      end

      # again, this is too naive, should actually parse the comments and update them
      def xmpfilter_update(line, line_results)
        line.gsub /# =>.*?$/, "# => #{line_results.join ', '}"
      end

      def add_stdout
        return unless file_result.has_stdout?
        new_body << "\n"
        file_result.stdout.each_line do |line|
          new_body << LineFormatter.new('', "#{STDOUT_PREFIX} ", line.chomp, options).call << "\n"
        end
      end

      def add_stderr
        return unless file_result.has_stderr?
        new_body << "\n"
        file_result.stderr.each_line do |line|
          new_body << LineFormatter.new('', "#{STDERR_PREFIX} ", line.chomp, options).call << "\n"
        end
      end

      def add_remaining_lines
        line_queue.each { |line, line_number| new_body << line }
      end

      def format_line(line, line_number, line_results)
        options = options().merge pad_to: alignment_strategy.line_length_for(line_number)
        formatted_line = if line_results.has_exception?
                           result = sprintf "%s: %s", line_results.exception.class_name, line_results.exception.message
                           LineFormatter.new(line, "#{EXCEPTION_PREFIX} ", result, options).call
                         elsif line_results.any?
                           LineFormatter.new(line, "#{RESULT_PREFIX} ", line_results.join(', '), options).call
                         else
                           line
                         end
        formatted_line + "\n"
      end

    end
  end
end
