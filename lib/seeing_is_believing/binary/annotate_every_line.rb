require 'stringio'
require 'seeing_is_believing/binary/comment_formatter'

require 'seeing_is_believing/binary'
require 'seeing_is_believing/binary/remove_annotations'
require 'seeing_is_believing/binary/find_comments'
require 'seeing_is_believing/binary/rewrite_comments'
require 'seeing_is_believing/binary/comment_lines'

class SeeingIsBelieving
  class Binary
    class AnnotateEveryLine
      def self.clean(uncleaned_body)
        RemoveAnnotations.call uncleaned_body, true
      end

      attr_accessor :results, :body
      def initialize(body, options={}, &annotater)
        self.options = options
        self.body    = body

        options = {
          filename:           (options[:as] || options[:filename]),
          require:            options[:require],
          load_path:          options[:load_path],
          encoding:           options[:encoding],
          stdin:              options[:stdin],
          timeout:            options[:timeout],
          debugger:           options[:debugger],
          ruby_executable:    options[:shebang],
          number_of_captures: options[:number_of_captures],
        }

        # This should so obviously not go here >.<
        # initializing this obj kicks off the entire lib!!
        self.results = SeeingIsBelieving.call body, options
      end

      def call
        @new_body ||= begin
          new_body = body_with_everything_annotated

          add_stdout_stderr_and_exceptions_to new_body

          options[:debugger].context "OUTPUT"
          new_body
        end
      end

      private

      attr_accessor :body, :options, :alignment_strategy

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
