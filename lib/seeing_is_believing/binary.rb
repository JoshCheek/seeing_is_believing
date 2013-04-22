require 'seeing_is_believing'
require 'seeing_is_believing/binary/arg_parser'
require 'seeing_is_believing/binary/print_results_next_to_lines'
require 'timeout'


class SeeingIsBelieving
  class Binary
    attr_accessor :argv, :stdin, :stdout, :stderr, :timeout_error

    def initialize(argv, stdin, stdout, stderr)
      self.argv   = argv
      self.stdin  = stdin
      self.stdout = stdout
      self.stderr = stderr
    end

    def call
      @exitstatus ||= if    flags_have_errors?          then print_errors          ; 1
                      elsif should_print_help?          then print_help            ; 0
                      elsif should_print_version?       then print_version         ; 0
                      elsif has_filename? && file_dne?  then print_file_dne        ; 1
                      elsif should_clean?               then print_cleaned_program ; 0
                      elsif invalid_syntax?             then print_syntax_error    ; 1
                      elsif program_timedout?           then print_timeout_error   ; 1
                      else                                   print_program         ; (results.has_exception? ? 1 : 0)
                      end
    end

    alias exitstatus call

    private

    def has_filename?
      flags[:filename]
    end

    def program_timedout?
      results
      timeout_error
    end

    def print_timeout_error
      stderr.puts "Timeout Error after #{@flags[:timeout]} seconds!"
    end

    def cleaned_body
      @body ||= PrintResultsNextToLines.remove_previous_output_from \
        flags[:program] || (file_is_on_stdin? && stdin.read) || File.read(flags[:filename])
    end

    def results
      @results ||= SeeingIsBelieving.call cleaned_body,
                                          filename:  (flags[:as] || flags[:filename]),
                                          require:   flags[:require],
                                          load_path: flags[:load_path],
                                          encoding:  flags[:encoding],
                                          stdin:     (file_is_on_stdin? ? '' : stdin),
                                          timeout:   flags[:timeout]
    rescue Timeout::Error
      self.timeout_error = true
    end

    def printer
      @printer ||= PrintResultsNextToLines.new cleaned_body, results, flags
    end

    def flags
      @flags ||= ArgParser.parse argv
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
      stdout.puts printer.call
    end

    def syntax_error_notice
      out, err, syntax_status = Open3.capture3 'ruby', '-c', stdin_data: cleaned_body
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
      stdout.print cleaned_body
    end
  end
end
