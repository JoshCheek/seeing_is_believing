require 'seeing_is_believing'
require 'seeing_is_believing/binary/parse_args'
require 'seeing_is_believing/binary/options'
require 'seeing_is_believing/binary/engine'

class SeeingIsBelieving
  module Binary
    SUCCESS_STATUS              = 0
    DISPLAYABLE_ERROR_STATUS    = 1 # e.g. user code raises an exception (we can display this in the output)
    NONDISPLAYABLE_ERROR_STATUS = 2 # e.g. SiB was invoked incorrectly

    def self.call(argv, stdin, stdout, stderr)
      options = Options.init(ParseArgs.call(argv), stdin, stdout, stderr)
      engine  = Engine.new options

      if options.print_help?
        stdout.puts options.help_screen
        return SUCCESS_STATUS
      end

      if options.print_version?
        stdout.puts SeeingIsBelieving::VERSION
        return SUCCESS_STATUS
      end

      if options.errors.any?
        stderr.puts *options.errors, *options.deprecations
        return NONDISPLAYABLE_ERROR_STATUS
      end

      if options.print_cleaned?
        stdout.print engine.cleaned_body
        return SUCCESS_STATUS
      end

      if engine.syntax_error?
        stderr.puts engine.syntax_error_message
        return NONDISPLAYABLE_ERROR_STATUS
      end

      engine.evaluate!

      if engine.timed_out?
        stderr.puts "Timeout Error after #{options.timeout_seconds} seconds!"
        return NONDISPLAYABLE_ERROR_STATUS
      end

      # TODO: it feels like there should be a printer object?
      # ie shouldn't all the outputs be json if they specified json?
      if options.result_as_json?
        require 'json'
        stdout.puts JSON.dump(result_as_data_structure(engine.results))
        return SUCCESS_STATUS
      end

      stdout.print engine.annotated_body

      if options.inherit_exit_status?
        engine.results.exitstatus
      elsif engine.results.exitstatus.zero?
        SUCCESS_STATUS
      else
        DISPLAYABLE_ERROR_STATUS # the error is rendered in the annotated body
      end
    end

    private

    def self.result_as_data_structure(results)
      exception = results.has_exception? && { line_number_in_this_file: results.exception.line_number,
                                              class_name:               results.exception.class_name,
                                              message:                  results.exception.message,
                                              backtrace:                results.exception.backtrace,
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
