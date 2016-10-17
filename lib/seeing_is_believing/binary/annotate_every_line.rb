class SeeingIsBelieving
  module Binary
    class AnnotateEveryLine
      def self.call(body, results, options)
        new(body, results, options).call
      end

      def initialize(body, results, options={})
        @options        = options
        @body           = body
        @results        = results
        @format_strings = {}
      end

      def call
        @new_body ||= begin
          require 'seeing_is_believing/binary/comment_lines'
          require 'seeing_is_believing/binary/format_comment'
          exception_text = @options[:markers][:exception][:prefix]
          value_text     = @options[:markers][:value][:prefix]

          alignment_strategy = @options[:alignment_strategy].new(@body)
          exception_lineno   = @results.has_exception? ? @results.exception.line_number : -1
          new_body = CommentLines.call @body do |line, line_number|
            options = @options.merge pad_to: alignment_strategy.line_length_for(line_number)
            if exception_lineno == line_number
              result = sprintf "%s: %s", @results.exception.class_name, @results.exception.message.gsub("\n", '\n')
              FormatComment.call(line.size, exception_text, result, options)
            elsif @results[line_number].any?
              if @options[:interline_align]
                result = format_string_for_line(line_number) % @results[line_number].map { |result| result.gsub "\n", '\n' }
              else
                result = @results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              end
              FormatComment.call(line.size, value_text, result, options)
            else
              ''
            end
          end

          require 'seeing_is_believing/binary/annotate_end_of_file'
          AnnotateEndOfFile.add_stdout_stderr_and_exceptions_to new_body, @results, @options

          new_body
        end
      end

      private

      def format_string_for_line(lineno)
        group = groups_with_same_number_of_results[lineno]
        format_string_for(group, lineno)
      end

      def groups_with_same_number_of_results
        @grouped_by_no_results ||= begin
           length = 0
           groups = 1.upto(@results.num_lines)
                     .slice_before { |num|
                       new_length = @results[num].length
                       slice      = length != new_length
                       length     = new_length
                       slice
                     }.to_a

           groups.each_with_object Hash.new do |group, lineno_to_group|
             group.each { |lineno| lineno_to_group[lineno] = group }
           end
        end
      end

      def format_string_for(group, lineno)
        @format_strings[lineno] ||= begin
          index = group.index lineno
          group
            .map { |lineno| @results[lineno] }
            .transpose
            .map { |col|
              lengths = col.map(&:length)
              max     = lengths.max
              crnt    = lengths[index]
              "%-#{crnt}s,#{" "*(max-crnt)} "
            }
            .join
            .sub(/, *$/, "")
        end
      end
    end
  end
end
