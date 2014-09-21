require 'seeing_is_believing/code'

class SeeingIsBelieving
  module Binary
    class AnnotateXmpfilterStyle
      def self.prepare_body(uncleaned_body, markers)
        # TODO: There's definitely a lot of overlap in responsibilities with invoking of parser
        # and this is a conspicuous hack, since this functionality should really be provided by RemoveAnnotations
        code = Code.new(uncleaned_body)
        code.inline_comments
            .select       { |c|  c.whitespace_col == 0 } # TODO: Would be nice to support indentation here
            .slice_before { |c|  c.text.start_with? markers[:value]  }
            .flat_map     { |cs|
              consecutives = cs.each_cons(2).take_while { |c1, c2| c1.line_number.next == c2.line_number }
              cs[1, consecutives.size]
            }
            .select { |c| c.text.start_with? markers[:nextline] }
            .each { |c|
              range_with_preceding_newline = code.range_for(c.comment_range.begin_pos.pred, c.comment_range.end_pos)
              code.rewriter.remove range_with_preceding_newline
            }
        partially_cleaned_body = code.rewriter.process

        require 'seeing_is_believing/binary/remove_annotations'
        RemoveAnnotations.call partially_cleaned_body, false, markers
      end

      def self.expression_wrapper(markers)
        -> program, number_of_captures {
          inspect_linenos = []
          pp_linenos      = []
          Code.new(program).inline_comments.each do |c|
            next unless c.text.start_with? markers[:value].sub(/\s+$/, '')
            c.whitespace_col == 0 ? pp_linenos      << c.line_number - 1
                                  : inspect_linenos << c.line_number
          end

          InspectExpressions.call program,
                                  number_of_captures,
                                  before_all: -> {
                                    # TODO: this is duplicated with the InspectExpressions class
                                    number_of_captures_as_str = number_of_captures.inspect
                                    number_of_captures_as_str = 'Float::INFINITY' if number_of_captures == Float::INFINITY
                                    "begin; require 'pp'; $SiB.max_line_captures = #{number_of_captures_as_str}; $SiB.num_lines = #{program.lines.count}; "
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
        }
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
          require 'seeing_is_believing/binary' # defines the markers
          require 'seeing_is_believing/binary/rewrite_comments'
          require 'seeing_is_believing/binary/comment_formatter'
          new_body = RewriteComments.call @body do |comment|
            if !comment.text[value_regex]
              [comment.whitespace, comment.text]
            elsif comment.whitespace_col == 0
              # TODO: check that having multiple mult-line output values here looks good (e.g. avdi's example in a loop)
              result          = @results[comment.line_number-1, :pp].map { |result| result.chomp }.join(', ')
              comment_lines   = result.each_line.map.with_index do |comment_line, result_offest|
                if result_offest == 0
                  CommentFormatter.call(comment.whitespace_col, value_marker, comment_line.chomp, @options)
                else
                  CommentFormatter.call(comment.whitespace_col, nextline_marker, comment_line.chomp, @options)
                end
              end
              [comment.whitespace, comment_lines.join("\n")]
            else
              result = @results[comment.line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              [comment.whitespace, CommentFormatter.call(comment.text_col, value_marker, result, @options)]
            end
          end

          require 'seeing_is_believing/binary/annotate_end_of_file'
          AnnotateEndOfFile.add_stdout_stderr_and_exceptions_to new_body, @results, @options

          # What's w/ this debugger? maybe this should move higher?
          @options[:debugger].context "OUTPUT"
          new_body
        end
      end

      def value_marker
        @value_marker ||= @options[:markers][:value]
      end

      def nextline_marker
        @xnextline_marker ||= @options[:markers][:nextline]
      end

      def value_regex
        @value_regex ||= /\A#{value_marker.sub(/\s+$/, '')}/
      end
    end
  end
end
