require 'stringio'
require 'seeing_is_believing/queue'
require 'seeing_is_believing/has_exception'
require 'seeing_is_believing/binary/comment_formatter'
require 'seeing_is_believing/binary/remove_previous_annotations'
require 'seeing_is_believing/binary/clean_body'
require 'seeing_is_believing/binary/rewrite_comments'
require 'seeing_is_believing/binary/comment_lines'

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
    class AddAnnotations
      include HasException

      def self.method_from_options(*args)
        define_method(args.first) { options.fetch *args }
      end

      method_from_options :filename, nil
      method_from_options :start_line # rename: line_to_begin_recording
      method_from_options :end_line   # rename: line_to_end_recording
      method_from_options :line_length,    Float::INFINITY
      method_from_options :result_length,  Float::INFINITY
      method_from_options :xmpfilter_style
      method_from_options :debugger

      attr_accessor :file_result
      def initialize(body, options={})
        self.options = options
        body = CleanBody.call body, !xmpfilter_style
        results = SeeingIsBelieving.call body,
                                         filename:     (options[:as] || options[:filename]),
                                         require:      options[:require],
                                         load_path:    options[:load_path],
                                         encoding:     options[:encoding],
                                         stdin:        options[:stdin],
                                         timeout:      options[:timeout],
                                         debugger:     debugger

        self.file_result = results

        new_body = if xmpfilter_style
          RewriteComments.call body do |line_number, line, whitespace, comment|
            # FIXME: can we centralize these regexes?
            if !comment[/\A#\s*=>/]
              [whitespace, comment]
            elsif line.empty?
              # should go through comment formatter
              [whitespace, "# => #{results[line_number-1].map { |result| result.gsub "\n", '\n' }.join(', ')}"] # FIXME: NEED TO CONSIDER THE LINE LENGTH
            else
              # should go through comment formatter
              [whitespace, "# => #{results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')}"] # FIXME: NEED TO CONSIDER THE LINE LENGTH
            end
          end
        else
          alignment_strategy = options[:alignment_strategy].new body, start_line, end_line
          CommentLines.call body do |line, line_number|
            options = options().merge pad_to: alignment_strategy.line_length_for(line_number)
            if line_number < start_line || end_line < line_number
              ''
            elsif results[line_number].has_exception?
              exception = results[line_number].exception
              result    = sprintf "%s: %s", exception.class_name, exception.message.gsub("\n", '\n')
              CommentFormatter.new(line, "# ~> ", result, options).call
            elsif results[line_number].any?
              result  = results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              CommentFormatter.call(line, "# => ", result, options)
            else
              ''
            end
          end
        end

        output = ""

        if file_result.has_stdout?
          output << "\n"
          file_result.stdout.each_line do |line|
            output << CommentFormatter.call('', "# >> ", line.chomp, options()) << "\n"
          end
        end

        if file_result.has_stderr?
          output << "\n"
          file_result.stderr.each_line do |line|
            output << CommentFormatter.call('', "# !> ", line.chomp, options()) << "\n"
          end
        end

        add_exception output, results

        if new_body["\n__END__\n"]
          new_body.sub! "\n__END__\n", "\n#{output}__END__\n"
        else
          new_body << "\n" << output
        end

        new_body = if debugger.enabled?
          debugger.context("RESULT") { new_body }.to_s
        else
          new_body
        end


        @new_body = new_body
      end

      def call
        @new_body
      end


      def new_body
        @new_body ||= ''
      end

      # def call
      #   @printed_program ||= begin
      #     # can we put the call to chomp into the line_queue initialization code?
      #     line_queue.until { |line, line_number| SyntaxAnalyzer.begins_data_segment?(line.chomp) }
      #               .each  { |line, line_number| add_line line, line_number }
      #     add_stdout
      #     add_stderr
      #     add_exception
      #     add_remaining_lines
      #     if debugger.enabled?
      #       debugger.context("RESULT") { new_body }.to_s
      #     else
      #       new_body
      #     end
      #   end
      # end

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
          new_body << xmpfilter_update(line, file_result[line_number - 1]) # There is probably a bug in this since it doesn't go through the LineFormatter it can probably be to long
        elsif should_record && xmpfilter_style
          new_body << xmpfilter_update(line, file_result[line_number]) # There is probably a bug in this since it doesn't go through the LineFormatter it can probably be to long
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
        line.gsub /# =>.*?$/, "# => #{line_results.join(', ').gsub("\n", '\n')}"
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

      def add_exception(output, file_result)
        return unless file_result.has_exception?
        exception = file_result.exception
        output << "\n"
        output << CommentFormatter.new('', "# ~> ", exception.class_name, options).call << "\n"
        exception.message.each_line do |line|
          output << CommentFormatter.new('', "# ~> ", line.chomp, options).call << "\n"
        end
        output << "# ~>\n"
        exception.backtrace.each do |line|
          output << CommentFormatter.new('', "# ~> ", line.chomp, options).call << "\n"
        end
      end

      def add_remaining_lines
        line_queue.each { |line, line_number| new_body << line }
      end

      def format_line(line, line_number, line_results)
        options = options().merge pad_to: alignment_strategy.line_length_for(line_number)
        formatted_line = if line_results.has_exception?
                           result = sprintf "%s: %s", line_results.exception.class_name, line_results.exception.message.gsub("\n", '\n')
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
