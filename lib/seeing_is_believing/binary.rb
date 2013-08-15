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
        else                                             print_program          ; program_exit_status
        end
      end
    end

    private

    attr_accessor :flags, :interpolated_program

    def program_exit_status
      if flags[:inherit_exit_status]
        results.exitstatus
      elsif results.has_exception?
        DISPLAYABLE_ERROR_STATUS
      else
        SUCCESS_STATUS
      end
    end

    def parse_flags
      self.flags = ParseArgs.call argv, stdout
    end

    def has_filename?
      flags[:filename]
    end

    def evaluate_program
      self.interpolated_program = printer.call
    rescue Timeout::Error
      self.timeout_error = true
    rescue Exception
      self.unexpected_exception = $!
    end

    # could we make this more obvious? I'd like to to be clear from #call
    # that this is when the program gets evaluated
    def program_timedout?
      timeout_error
    end

    def print_timeout_error
      stderr.puts "Timeout Error after #{@flags[:timeout]} seconds!"
    end

    def body
      @body ||= (flags[:program] || (file_is_on_stdin? && stdin.read) || File.read(flags[:filename]))
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

    def printer
      @printer ||= AddAnnotations.new body, flags.merge(stdin: (file_is_on_stdin? ? '' : stdin))
    end

    def results
      printer.results
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

    def file_is_on_stdin?
      flags[:filename].nil? && flags[:program].nil?
    end

    def file_dne?
      !File.exist?(flags[:filename])
    end

    def print_file_dne
      stderr.puts "#{flags[:filename]} does not exist!"
    end

    def print_program
      stdout.puts interpolated_program
    end

    def syntax_error_notice
      out, err, syntax_status = Open3.capture3 flags[:shebang], '-c', stdin_data: body
      return err unless syntax_status.success?
    end

    def invalid_syntax?
      !!syntax_error_notice
    end

    def print_syntax_error
      stderr.puts syntax_error_notice
    end

    def should_clean?
      flags[:clean]
    end

    def print_cleaned_program
      stdout.print CleanBody.call(body, true)
    end
  end
end
