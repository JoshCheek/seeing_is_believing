require 'seeing_is_believing/binary' # defines the markers
require 'seeing_is_believing/binary/format_comment'

class SeeingIsBelieving
  module Binary
    module AnnotateEndOfFile
      extend self

      def add_stdout_stderr_and_exceptions_to(new_body, results, options)
        output = stdout_ouptut_for(results, options)    <<
                 stderr_ouptut_for(results, options)    <<
                 exception_output_for(results, options)

        code = Code.new(new_body)
        code.rewriter.insert_after_multi code.body_range, output
        new_body.replace code.rewriter.process
      end

      def stdout_ouptut_for(results, options)
        return '' unless results.has_stdout?
        output = "\n"
        results.stdout.each_line do |line|
          output << FormatComment.call(0, options[:markers][:stdout][:prefix], line.chomp, options) << "\n"
        end
        output
      end

      def stderr_ouptut_for(results, options)
        return '' unless results.has_stderr?
        output = "\n"
        results.stderr.each_line do |line|
          output << FormatComment.call(0, options[:markers][:stderr][:prefix], line.chomp, options) << "\n"
        end
        output
      end

      def exception_output_for(results, options)
        return '' unless results.has_exception?
        exception_marker = options[:markers][:exception][:prefix]
        exception = results.exception
        output = "\n"
        output << FormatComment.new(0, exception_marker, exception.class_name, options).call << "\n"
        exception.message.each_line do |line|
          output << FormatComment.new(0, exception_marker, line.chomp, options).call << "\n"
        end
        output << exception_marker.sub(/\s+$/, '') << "\n"
        exception.backtrace.each do |line|
          output << FormatComment.new(0, exception_marker, line.chomp, options).call << "\n"
        end
        output
      end
    end
  end
end
