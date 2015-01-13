require 'seeing_is_believing/code'

class SeeingIsBelieving
  module Binary
    class AnnotateXmpfilterStyle
      def self.prepare_body(uncleaned_body, marker_regexes)
        require 'seeing_is_believing/binary/remove_annotations'
        RemoveAnnotations.call uncleaned_body, false, marker_regexes
      end

      def self.expression_wrapper(markers, marker_regexes)
        lambda do |program, filename, max_line_captures|
          inspect_linenos = []
          pp_linenos      = []
          Code.new(program).inline_comments.each do |c|
            next unless c.text[marker_regexes[:value]]
            c.whitespace_col == 0 ? pp_linenos      << c.line_number - 1
                                  : inspect_linenos << c.line_number
          end

          Annotate.call program,
                        filename,
                        max_line_captures,
                        before_all: -> {
                          # TODO: this is duplicated with the InspectExpressions class
                          max_line_captures_as_str = max_line_captures.inspect
                          max_line_captures_as_str = 'Float::INFINITY' if max_line_captures == Float::INFINITY
                          "require 'pp'; $SiB.record_filename #{filename.inspect}; $SiB.record_max_line_captures #{max_line_captures_as_str}; $SiB.num_lines = #{program.lines.count}; "
                        },
                        after_each: -> line_number {
                          should_inspect = inspect_linenos.include?(line_number)
                          should_pp      = pp_linenos.include?(line_number)
                          inspect        = "$SiB.record_result(:inspect, #{line_number}, v)"
                          pp             = "$SiB.record_result(:pp, #{line_number}, v) { PP.pp v, '', 74 }" # TODO: Is 74 the right value? Prob not, I think it's 80(default width) - 1(comment width) - 5(" => {"), but if I allow indented `# => `, then that would need to be less than 74 (idk if I actually do this or not, though :P)

                          if    should_inspect && should_pp then ").tap { |v| #{inspect}; #{pp} }"
                          elsif should_inspect              then ").tap { |v| #{inspect} }"
                          elsif should_pp                   then ").tap { |v| #{pp} }"
                          else                                   ")"
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

      # TODO: I think that this should respect the alignment strategy
      # and we should just add a new alignment strategy for default xmpfilter style
      def call
        @new_body ||= begin
          # TODO: doesn't currently realign output markers, do we want to do that?
          require 'seeing_is_believing/binary/rewrite_comments'
          require 'seeing_is_believing/binary/format_comment'
          include_lines = []

          if @results.has_exception?
            exception_result  = sprintf "%s: %s", @results.exception.class_name, @results.exception.message.gsub("\n", '\n')
            exception_lineno  = @results.exception.line_number
            include_lines << exception_lineno
          end

          new_body = RewriteComments.call @body, include_lines: include_lines do |comment|
            exception_on_line  = exception_lineno == comment.line_number
            annotate_this_line = comment.text[value_regex]
            pp_annotation      = annotate_this_line && comment.whitespace_col.zero?
            normal_annotation  = annotate_this_line && !pp_annotation
            if exception_on_line && annotate_this_line
              [comment.whitespace, FormatComment.call(comment.text_col, value_marker, exception_result, @options)]
            elsif exception_on_line
              whitespace = comment.whitespace
              whitespace = " " if whitespace.empty?
              [whitespace, FormatComment.call(0, exception_marker, exception_result, @options)]
            elsif normal_annotation
              result = @results[comment.line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              [comment.whitespace, FormatComment.call(comment.text_col, value_marker, result, @options)]
            elsif pp_annotation
              # result = sprintf "%s: %s", @results.exception.class_name, @results.exception.message.gsub("\n", '\n')
              # CommentFormatter.call(line.size, exception_marker, result, options)
              # TODO: check that having multiple mult-line output values here looks good (e.g. avdi's example in a loop)
              result          = @results[comment.line_number-1, :pp].map { |result| result.chomp }.join(', ')
              comment_lines   = result.each_line.map.with_index do |comment_line, result_offest|
                if result_offest == 0
                  FormatComment.call(comment.whitespace_col, value_marker, comment_line.chomp, @options)
                else
                  FormatComment.call(comment.whitespace_col, nextline_marker, comment_line.chomp, @options)
                end
              end
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

      def value_marker
        @value_marker ||= @options.fetch(:markers).fetch(:value)
      end

      def nextline_marker
        @xnextline_marker ||= ('#' + ' '*value_marker.size.pred)
      end

      def exception_marker
        @exception_marker ||= @options.fetch(:markers).fetch(:exception)
      end

      def value_regex
        @value_regex ||= @options.fetch(:marker_regexes).fetch(:value)
      end
    end
  end
end
