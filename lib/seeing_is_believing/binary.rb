require 'seeing_is_believing'
require 'seeing_is_believing/binary/parse_args'
require 'seeing_is_believing/binary/annotate_every_line'
require 'seeing_is_believing/binary/annotate_xmpfilter_style'
require 'seeing_is_believing/binary/remove_annotations'
require 'timeout'


class SeeingIsBelieving
  class Binary
    SUCCESS_STATUS              = 0
    DISPLAYABLE_ERROR_STATUS    = 1 # e.g. there was an error, but the output is legit (we can display exceptions)
    NONDISPLAYABLE_ERROR_STATUS = 2 # e.g. an error like incorrect invocation or syntax that can't be displayed in the input program

    VALUE_MARKER     = "# => "
    EXCEPTION_MARKER = "# ~> "
    STDOUT_MARKER    = "# >> "
    STDERR_MARKER    = "# !> "

    VALUE_REGEX      = /\A#\s*=>/
    EXCEPTION_REGEX  = /\A#\s*~>/
    STDOUT_REGEX     = /\A#\s*>>/
    STDERR_REGEX     = /\A#\s*!>/



    attr_accessor :argv, :stdin, :stdout, :stderr, :timeout_error, :unexpected_exception

    def initialize(argv, stdin, stdout, stderr)
      self.argv   = argv
      self.stdin  = stdin
      self.stdout = stdout
      self.stderr = stderr
    end

    def call
      @exitstatus ||= begin
        flags = ParseArgs.call argv, stdout

        if flags[:errors].any?
          stderr.puts flags[:errors].join("\n")
          return NONDISPLAYABLE_ERROR_STATUS
        end

        if flags[:help]
          stdout.puts flags[:help]
          return SUCCESS_STATUS
        end

        if flags[:version]
          stdout.puts SeeingIsBelieving::VERSION
          return SUCCESS_STATUS
        end

        if flags[:filename] && !File.exist?(flags[:filename])
          stderr.puts "#{flags[:filename]} does not exist!"
          return NONDISPLAYABLE_ERROR_STATUS
        end

        # TODO: would like to move most of this work into either the arg parser or some class that interprets args
        file_is_on_stdin = !flags[:filename] && !flags[:program]
        flags[:stdin] = (file_is_on_stdin ? '' : stdin)
        body = ( flags[:program]                  ||
                 (file_is_on_stdin && stdin.read) ||
                 File.read(flags[:filename])
               )
        annotator_class = (flags[:xmpfilter_style] ? AnnotateXmpfilterStyle : AnnotateEveryLine)
        flags[:record_expressions] = annotator_class.expression_wrapper
        prepared_body = annotator_class.prepare_body(body)
        if flags[:clean]
          stdout.print RemoveAnnotations.call(prepared_body, true)
          return SUCCESS_STATUS
        end

        syntax_error_notice = syntax_error_notice_for(body, flags[:shebang])
        if syntax_error_notice
          stderr.puts syntax_error_notice
          return NONDISPLAYABLE_ERROR_STATUS
        end

        results, program_timedout, unexpected_exception = evaluate_program(prepared_body, flags)
        if program_timedout
          stderr.puts "Timeout Error after #{flags[:timeout]} seconds!"
          return NONDISPLAYABLE_ERROR_STATUS
        end

        if unexpected_exception.kind_of? BugInSib
          stderr.puts unexpected_exception.message
          return NONDISPLAYABLE_ERROR_STATUS
        end

        if unexpected_exception
          stderr.puts unexpected_exception.class,
                      unexpected_exception.message,
                      "",
                      unexpected_exception.backtrace
          return NONDISPLAYABLE_ERROR_STATUS
        end

        if flags[:result_as_json]
          require 'json'
          stdout.puts JSON.dump(result_as_data_structure(results))
          return SUCCESS_STATUS
        end

        # TODO: implement .call on class
        annotator = annotator_class.new prepared_body, results, flags
        stdout.print annotator.call
        if flags[:inherit_exit_status]
          results.exitstatus
        elsif results.has_exception?
          DISPLAYABLE_ERROR_STATUS
        else
          SUCCESS_STATUS
        end
      end
    end

    private

    def syntax_error_notice_for(body, shebang)
      out, err, syntax_status = Open3.capture3 shebang, '-c', stdin_data: body
      return err unless syntax_status.success?

      # The stdin_data may still be getting written when the pipe closes
      # This is because Ruby will stop reading from stdin if everything left is in the DATA segment, and the data segment is not referenced.
      # In this case, the Syntax is fine
      # https://bugs.ruby-lang.org/issues/9583
    rescue Errno::EPIPE
      return nil
    end

    def evaluate_program(body, flags)
      results = SeeingIsBelieving.call body,
                                       flags.merge(filename:           (flags[:as] || flags[:filename]),
                                                   ruby_executable:    flags[:shebang],
                                                   evaluate_with:      flags.fetch(:evaluator),
                                                  )
      return results, nil, nil
    rescue Timeout::Error
      return nil, true, nil
    rescue Exception
      return nil, false, $!
    end

    def result_as_data_structure(results)
      exception = results.has_exception? && { line_number_in_this_file: results.exception.line_number,
                                              class_name:               results.exception.class_name,
                                              message:                  results.exception.message,
                                              backtrace:                results.exception.backtrace
                                            }
      { stdout:      results.stdout,
        stderr:      results.stderr,
        exit_status: results.exitstatus,
        exception:   exception,
        lines:       results.each.with_object(Hash.new).with_index(1) { |(result, hash), line_number| hash[line_number] = result },
      }
    end
  end
end
