require 'stringio'
require 'seeing_is_believing/binary/comment_formatter'

require 'seeing_is_believing/binary'
require 'seeing_is_believing/binary/clean_body'
require 'seeing_is_believing/binary/find_comments'
require 'seeing_is_believing/binary/rewrite_comments'
require 'seeing_is_believing/binary/comment_lines'

class SeeingIsBelieving
  class Binary
    class AnnotateXmpfilterStyle

      def self.method_from_options(*args)
        define_method(args.first) { options.fetch *args }
      end

      method_from_options :filename, nil
      method_from_options :xmpfilter_style
      method_from_options :debugger

      attr_accessor :results, :body
      def initialize(uncleaned_body, options={}, &annotater)
        self.options = options
        self.body    = CleanBody.call uncleaned_body, !xmpfilter_style

        options = {
          filename:           (options[:as] || options[:filename]),
          require:            options[:require],
          load_path:          options[:load_path],
          encoding:           options[:encoding],
          stdin:              options[:stdin],
          timeout:            options[:timeout],
          debugger:           debugger,
          ruby_executable:    options[:shebang],
          number_of_captures: options[:number_of_captures],
        }

        if xmpfilter_style
          options[:require] << 'pp'
          finder          = FindComments.new(body)
          inspect_linenos = []
          pp_linenos      = []

          finder.comments.each { |c|
            next unless c.comment[VALUE_REGEX]
            if c.code.empty?
              pp_linenos << c.line_number - 1
            else
              inspect_linenos << c.line_number
            end
          }

          options[:after_each] = -> line_number {
            should_inspect = inspect_linenos.include?(line_number)
            should_pp      = pp_linenos.include?(line_number)
            inspect        = "$SiB.record_result(:inspect, #{line_number}, v)"
            pp             = "$SiB.record_result(:pp, #{line_number}, v) { PP.pp v, '', 74 }" # TODO: Is 74 the right value?

            if    should_inspect && should_pp then ").tap { |v| #{inspect}; #{pp} }"
            elsif should_inspect              then ").tap { |v| #{inspect} }"
            elsif should_pp                   then ").tap { |v| #{pp} }"
            else                                   ")"
            end
          }
        end

        # This should so obviously not go here >.<
        # initializing this obj kicks off the entire lib!!
        self.results = SeeingIsBelieving.call body, options
      end

      def call
        @new_body ||= begin
          new_body = if xmpfilter_style
                       body_with_updated_annotations
                     else
                       body_with_everything_annotated
                     end

          add_stdout_stderr_and_exceptions_to new_body

          debugger.context "OUTPUT"
          new_body
        end
      end

      private

      attr_accessor :body, :options, :alignment_strategy

      # doesn't currently realign output markers, do we want to do that?
      def body_with_updated_annotations
        RewriteComments.call body do |line_number, line_to_whitespace, whitespace, comment|
          if !comment[VALUE_REGEX]
            [whitespace, comment]
          elsif line_to_whitespace.empty?
            result = results[line_number-1, :pp].map { |result| result.chomp }.join(', ') # TODO: CommentFormatter#initialize escapes newlines, need to be able to pass in that this shouldn't happen in this case
            [whitespace, CommentFormatter.call(whitespace.size, VALUE_MARKER, result, options)]
          else
            result = results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
            [whitespace, CommentFormatter.call(line_to_whitespace.size + whitespace.size, VALUE_MARKER, result, options)]
          end
        end
      end

      def body_with_everything_annotated
        alignment_strategy = options[:alignment_strategy].new(body)
        exception_lineno   = results.has_exception? ? results.exception.line_number : -1
        CommentLines.call body do |line, line_number|
          options = options().merge pad_to: alignment_strategy.line_length_for(line_number)
          if exception_lineno == line_number
            result = sprintf "%s: %s", results.exception.class_name, results.exception.message.gsub("\n", '\n')
            CommentFormatter.call(line.size, EXCEPTION_MARKER, result, options)
          elsif results[line_number].any?
            result  = results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
            CommentFormatter.call(line.size, VALUE_MARKER, result, options)
          else
            ''
          end
        end
      end

      def add_stdout_stderr_and_exceptions_to(new_body)
        output = stdout_ouptut_for(results)    <<
                 stderr_ouptut_for(results)    <<
                 exception_output_for(results)

        # this technically could find an __END__ in a string or whatever
        # going to just ignore that, though
        if new_body[/^__END__$/]
          new_body.sub! "\n__END__", "\n#{output}__END__"
        else
          new_body << "\n" unless new_body.end_with? "\n"
          new_body << output
        end
      end

      def stdout_ouptut_for(results)
        return '' unless results.has_stdout?
        output = "\n"
        results.stdout.each_line do |line|
          output << CommentFormatter.call(0, STDOUT_MARKER, line.chomp, options()) << "\n"
        end
        output
      end

      def stderr_ouptut_for(results)
        return '' unless results.has_stderr?
        output = "\n"
        results.stderr.each_line do |line|
          output << CommentFormatter.call(0, STDERR_MARKER, line.chomp, options()) << "\n"
        end
        output
      end

      def exception_output_for(results)
        return '' unless results.has_exception?
        exception = results.exception
        output = "\n"
        output << CommentFormatter.new(0, EXCEPTION_MARKER, exception.class_name, options).call << "\n"
        exception.message.each_line do |line|
          output << CommentFormatter.new(0, EXCEPTION_MARKER, line.chomp, options).call << "\n"
        end
        output << EXCEPTION_MARKER.sub(/\s+$/, '') << "\n"
        exception.backtrace.each do |line|
          output << CommentFormatter.new(0, EXCEPTION_MARKER, line.chomp, options).call << "\n"
        end
        output
      end

    end
  end
end
