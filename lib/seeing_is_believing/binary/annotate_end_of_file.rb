class SeeingIsBelieving
  class Binary
    module AnnotateEndOfFile
      extend self

      def add_stdout_stderr_and_exceptions_to(new_body, results, options)
        output = stdout_ouptut_for(results, options)    <<
                 stderr_ouptut_for(results, options)    <<
                 exception_output_for(results, options)

        # this technically could find an __END__ in a string or whatever
        # going to just ignore that, though
        if new_body[/^__END__$/]
          new_body.sub! "\n__END__", "\n#{output}__END__"
        else
          new_body << "\n" unless new_body.end_with? "\n"
          new_body << output
        end
      end

      def stdout_ouptut_for(results, options)
        return '' unless results.has_stdout?
        output = "\n"
        results.stdout.each_line do |line|
          output << CommentFormatter.call(0, STDOUT_MARKER, line.chomp, options) << "\n"
        end
        output
      end

      def stderr_ouptut_for(results, options)
        return '' unless results.has_stderr?
        output = "\n"
        results.stderr.each_line do |line|
          output << CommentFormatter.call(0, STDERR_MARKER, line.chomp, options) << "\n"
        end
        output
      end

      def exception_output_for(results, options)
        return '' unless results.has_exception?
        require 'seeing_is_believing/binary/comment_formatter'
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
