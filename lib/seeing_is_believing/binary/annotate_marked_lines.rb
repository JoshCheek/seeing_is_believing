# encoding: utf-8
require 'seeing_is_believing/code'

# *sigh* need to find a way to join the annotators.
# They are sinful ugly, kinda hard to work with,
# and absurdly duplicated.

class SeeingIsBelieving
  module Binary
    # Based on the behaviour of xmpfilger (a binary in the rcodetools gem)
    # See https://github.com/JoshCheek/seeing_is_believing/issues/44 for more details
    class AnnotateMarkedLines
      def self.map_markers_to_linenos(program, markers)
        value_regex      = markers[:value][:regex]
        recordable_lines = []
        inspect_linenos  = []
        pp_map           = {}
        WrapExpressions.call program, before_each: -> line_number {
          recordable_lines << line_number
          ''
        }

        Code.new(program).inline_comments.each do |c|
          next unless c.text[value_regex]
          if c.whitespace_col == 0
            lineno = c.line_number
            loop do
              lineno -= 1
              break if recordable_lines.include?(lineno) || lineno.zero?
            end
            pp_map[c.line_number] = lineno
          else
            inspect_linenos << c.line_number
          end
        end

        return inspect_linenos, pp_map
      end

      def self.code_rewriter(markers)
        lambda do |program|
          inspect_linenos, pp_map = map_markers_to_linenos(program, markers)
          pp_linenos = pp_map.values

          should_inspect = false
          should_pp      = false
          WrapExpressions.call \
            program,
            before_each: -> line_number {
              # 74 b/c pretty print_defaults to 79 (guessing 80 chars with 1 reserved for newline), and
              # 79 - "# => ".length # => 4
              inspect        = "$SiB.record_result(:inspect, #{line_number}, ("
              pp             = "$SiB.record_result(:pp, #{line_number}, ("

              should_inspect = inspect_linenos.include? line_number
              should_pp      = pp_linenos.include?      line_number

              if    should_inspect && should_pp then "#{pp}#{inspect}"
              elsif should_inspect              then inspect
              elsif should_pp                   then pp
              else                                   ""
              end
            },
            after_each:  -> line_number {
              inspect = "))"
              pp      = ")) { |v| PP.pp v, '', 74 }"

              should_inspect = inspect_linenos.include? line_number
              should_pp      = pp_linenos.include?      line_number

              if    should_inspect && should_pp then "#{inspect}#{pp}"
              elsif should_inspect              then inspect
              elsif should_pp                   then pp
              else                                   ""
              end
            }
        end
      end

      def self.call(body, results, options)
        new(body, results, options).call
      end

      def initialize(body, results, options={})
        @options = options
        @body    = body
        @results = results
      end

      # seems like maybe this should respect the alignment strategy (not what xmpfilter does, but there are other ways I'd like to deviate anyway)
      # and we should just add a new alignment strategy for default xmpfilter style
      def call
        @new_body ||= begin
          require 'seeing_is_believing/binary/rewrite_comments'
          require 'seeing_is_believing/binary/format_comment'
          include_lines = []

          if @results.has_exception?
            exception_result  = sprintf "%s: %s", @results.exception.class_name, @results.exception.message.gsub("\n", '\n')
            exception_lineno  = @results.exception.line_number
            include_lines << exception_lineno
          end

          _, pp_map = self.class.map_markers_to_linenos(@body, @options[:markers])
          new_body = RewriteComments.call @body, include_lines: include_lines do |comment|
            exception_on_line  = exception_lineno == comment.line_number
            annotate_this_line = comment.text[value_regex]
            pp_annotation      = annotate_this_line && comment.whitespace_col.zero?
            normal_annotation  = annotate_this_line && !pp_annotation
            if exception_on_line && annotate_this_line
              [comment.whitespace, FormatComment.call(comment.text_col, value_prefix, exception_result, @options)]
            elsif exception_on_line
              whitespace = comment.whitespace
              whitespace = " " if whitespace.empty?
              [whitespace, FormatComment.call(0, exception_prefix, exception_result, @options)]
            elsif normal_annotation
              annotation = @results[comment.line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              [comment.whitespace, FormatComment.call(comment.text_col, value_prefix, annotation, @options)]
            elsif pp_annotation
              result     = @results[pp_map[comment.line_number], :pp]
              annotation = result.map { |result| result.chomp }.join("\n,") # ["1\n2", "1\n2", ...
              swap_leading_whitespace_in_multiline_comment(annotation)
              comment_lines = annotation.each_line.map.with_index do |comment_line, result_offest|
                if result_offest == 0
                  FormatComment.call(comment.whitespace_col, value_prefix, comment_line.chomp, @options)
                else
                  leading_whitespace = " " * comment.text_col
                  leading_whitespace << FormatComment.call(comment.whitespace_col, nextline_prefix, comment_line.chomp, @options)
                end
              end
              comment_lines = [value_prefix.rstrip] if comment_lines.empty?
              [comment.whitespace, comment_lines.join("\n")]
            else
              [comment.whitespace, comment.text]
            end
          end

          require 'seeing_is_believing/binary/annotate_end_of_file'
          AnnotateEndOfFile.add_stdout_stderr_and_exceptions_to new_body, @results, @options

          new_body
        end
      end

      def value_prefix
        @value_prefix ||= @options[:markers][:value][:prefix]
      end

      def nextline_prefix
        @nextline_prefix ||= ('#' + ' '*value_prefix.length.pred)
      end

      def exception_prefix
        @exception_prefix ||= @options[:markers][:exception][:prefix]
      end

      def value_regex
        @value_regex ||= @options[:markers][:value][:regex]
      end

      def swap_leading_whitespace_in_multiline_comment(comment)
        return if comment.scan("\n").size < 2
        return if comment[0] =~ /\S/
        nonbreaking_space = " "
        comment[0] = nonbreaking_space
      end
    end
  end
end
