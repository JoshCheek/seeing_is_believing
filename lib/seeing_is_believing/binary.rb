require 'seeing_is_believing'
require 'seeing_is_believing/binary/parse_args'
require 'seeing_is_believing/binary/add_annotations'
require 'seeing_is_believing/binary/clean_body'
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
        parse_flags

        if    flags_have_errors?                    then print_errors           ; NONDISPLAYABLE_ERROR_STATUS
        elsif should_print_help?                    then print_help             ; SUCCESS_STATUS
        elsif should_print_version?                 then print_version          ; SUCCESS_STATUS
        elsif has_filename? && file_dne?            then print_file_dne         ; NONDISPLAYABLE_ERROR_STATUS
        elsif should_clean?                         then print_cleaned_program  ; SUCCESS_STATUS
        elsif invalid_syntax?                       then print_syntax_error     ; NONDISPLAYABLE_ERROR_STATUS
        elsif (evaluate_program; program_timedout?) then print_timeout_error    ; NONDISPLAYABLE_ERROR_STATUS
        elsif something_blew_up?                    then print_unexpected_error ; NONDISPLAYABLE_ERROR_STATUS
        elsif output_as_json?                       then print_result_as_json   ; SUCCESS_STATUS
        else                                             print_program          ; exit_status
        end
      end
    end

    private

    attr_accessor :flags, :interpolated_program

    def parse_flags
      self.flags = ParseArgs.call argv, stdout
    end

    def flags_have_errors?
      flags[:errors].any?
    end

    def print_errors
      stderr.puts flags[:errors].join("\n")
    end

    def should_print_help?
      flags[:help]
    end

    def print_help
      stdout.puts flags[:help]
    end

    def should_print_version?
      flags[:version]
    end

    def print_version
      stdout.puts SeeingIsBelieving::VERSION
    end

    def has_filename?
      flags[:filename]
    end

    def file_dne?
      !File.exist?(flags[:filename])
    end

    def print_file_dne
      stderr.puts "#{flags[:filename]} does not exist!"
    end

    def should_clean?
      flags[:clean]
    end

    def print_cleaned_program
      stdout.print CleanBody.call(body, true)
    end

    def invalid_syntax?
      !!syntax_error_notice
    end

    def print_syntax_error
      stderr.puts syntax_error_notice
    end

    def evaluate_program
      self.interpolated_program = annotator.call
    rescue Timeout::Error
      self.timeout_error = true
    rescue Exception
      self.unexpected_exception = $!
    end

    def program_timedout?
      timeout_error
    end

    def print_timeout_error
      stderr.puts "Timeout Error after #{@flags[:timeout]} seconds!"
    end

    def something_blew_up?
      !!unexpected_exception
    end

    def print_unexpected_error
      if unexpected_exception.kind_of? BugInSib
        stderr.puts unexpected_exception.message
      else
        stderr.puts unexpected_exception.class, unexpected_exception.message, "", unexpected_exception.backtrace
      end
    end

    def output_as_json?
      flags[:result_as_json]
    end

    def print_program
      stdout.print interpolated_program
    end

    def body
      @body ||= (flags[:program] || (file_is_on_stdin? && stdin.read) || File.read(flags[:filename]))
    end

    def annotator
      @annotator ||= AddAnnotations.new body, flags.merge(stdin: (file_is_on_stdin? ? '' : stdin))
    end

    def results
      annotator.results
    end

    def file_is_on_stdin?
      flags[:filename].nil? && flags[:program].nil?
    end

    def syntax_error_notice
      @error_notice = begin
        out, err, syntax_status = Open3.capture3 flags[:shebang], '-c', stdin_data: body
        err unless syntax_status.success?

      # The stdin_data may still be getting written when the pipe closes
      # This is because Ruby will stop reading from stdin if everything left is in the DATA segment, and the data segment is not referenced.
      # In this case, the Syntax is fine
      # https://bugs.ruby-lang.org/issues/9583
      rescue Errno::EPIPE
        nil
      end
    end

    def print_result_as_json
      require 'json'
      stdout.puts JSON.dump result_as_data_structure
    end

    def result_as_data_structure
      results = annotator.results
      { stdout:      results.stdout,
        stderr:      results.stderr,
        exit_status: results.exitstatus,
        exception:   (if results.has_exception?
                       { line_number_in_this_file: results.each_with_line_number.find { |line_number, result| result.has_exception? }.first,
                         class_name:               results.exception.class_name,
                         message:                  results.exception.message,
                         backtrace:                results.exception.backtrace,
                       }
                     end),
        lines:       results.each_with_line_number.each_with_object(Hash.new) { |(line_number, result), hash|
                       hash[line_number] = { results:   result.to_a,
                                             exception: (if result.has_exception?
                                                          { class_name:               results.exception.class_name,
                                                            message:                  results.exception.message,
                                                            backtrace:                results.exception.backtrace,
                                                          }
                                                        end)
                       }
                     },
      }
    end

    def exit_status
      if flags[:inherit_exit_status]
        results.exitstatus
      elsif results.has_exception?
        DISPLAYABLE_ERROR_STATUS
      else
        SUCCESS_STATUS
      end
    end

  end
end
