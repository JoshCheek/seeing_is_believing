class SeeingIsBelieving
  class Binary
    class AnnotateXmpfilterStyle
      def self.prepare_body(uncleaned_body)
        require 'seeing_is_believing/binary/remove_annotations'
        RemoveAnnotations.call uncleaned_body, false
      end

      def self.expression_wrapper
        -> program, number_of_captures {
          require 'seeing_is_believing/binary/find_comments'
          finder          = FindComments.new(program)
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
                                    pp             = "$SiB.record_result(:pp, #{line_number}, v) { PP.pp v, '', 74 }" # TODO: Is 74 the right value?

                                    if    should_inspect && should_pp then ").tap { |v| #{inspect}; #{pp} }"
                                    elsif should_inspect              then ").tap { |v| #{inspect} }"
                                    elsif should_pp                   then ").tap { |v| #{pp} }"
                                    else                                   ")"
                                    end
                                  }
        }
      end

      def initialize(body, results, options={})
        @options = options
        @body    = body
        @results = results
      end

      def call
        @new_body ||= begin
          # TODO: doesn't currently realign output markers, do we want to do that?
          require 'seeing_is_believing/binary' # defines the markers
          require 'seeing_is_believing/binary/rewrite_comments'
          require 'seeing_is_believing/binary/comment_formatter'
          new_body = RewriteComments.call @body do |line_number, line_to_whitespace, whitespace, comment|
            if !comment[VALUE_REGEX]
              [whitespace, comment]
            elsif line_to_whitespace.empty?
              result = @results[line_number-1, :pp].map { |result| result.chomp }.join(', ') # TODO: CommentFormatter#initialize escapes newlines, need to be able to pass in that this shouldn't happen in this case
              [whitespace, CommentFormatter.call(whitespace.size, VALUE_MARKER, result, @options)]
            else
              result = @results[line_number].map { |result| result.gsub "\n", '\n' }.join(', ')
              [whitespace, CommentFormatter.call(line_to_whitespace.size + whitespace.size, VALUE_MARKER, result, @options)]
            end
          end

          require 'seeing_is_believing/binary/annotate_end_of_file'
          AnnotateEndOfFile.add_stdout_stderr_and_exceptions_to new_body, @results, @options

          # What's w/ this debugger? maybe this should move higher?
          @options[:debugger].context "OUTPUT"
          new_body
        end
      end
    end
  end
end
