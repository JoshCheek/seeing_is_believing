require 'stringio'
require 'seeing_is_believing/has_exception'
require 'seeing_is_believing/binary/comment_formatter'

require 'seeing_is_believing/binary'
require 'seeing_is_believing/binary/clean_body'
require 'seeing_is_believing/binary/rewrite_comments'
require 'seeing_is_believing/binary/comment_lines'

class SeeingIsBelieving
  class Binary
    class AddAnnotations
      include HasException

      def self.method_from_options(*args)
        define_method(args.first) { options.fetch *args }
      end

      method_from_options :filename, nil
      method_from_options :start_line # rename: line_to_begin_recording
      method_from_options :end_line   # rename: line_to_end_recording
      method_from_options :xmpfilter_style
      method_from_options :debugger

      attr_accessor :results, :body
      def initialize(uncleaned_body, options={}, &annotater)
        self.options = options
        self.body    = CleanBody.call uncleaned_body, !xmpfilter_style
        self.results = SeeingIsBelieving.call body,
                                              filename:           (options[:as] || options[:filename]),
                                              require:            options[:require],
                                              load_path:          options[:load_path],
                                              encoding:           options[:encoding],
                                              stdin:              options[:stdin],
                                              timeout:            options[:timeout],
                                              debugger:           debugger,
                                              ruby_executable:    options[:shebang],
                                              number_of_captures: options[:number_of_captures]
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
            result = results[line_number-1].map { |result| result.gsub "\n", '\n' }.join(', ')
            [whitespace, CommentFormatter.call(whitespace.size, VALUE_MARKER, result, options)]
          else
            result = results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
            [whitespace, CommentFormatter.call(line_to_whitespace.size + whitespace.size, VALUE_MARKER, result, options)]
          end
        end
      end

      def body_with_everything_annotated
        alignment_strategy = options[:alignment_strategy].new body, start_line, end_line
        CommentLines.call body do |line, line_number|
          options = options().merge pad_to: alignment_strategy.line_length_for(line_number)
          if line_number < start_line || end_line < line_number
            ''
          elsif results[line_number].has_exception?
            exception = results[line_number].exception
            result    = sprintf "%s: %s", exception.class_name, exception.message.gsub("\n", '\n')
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
