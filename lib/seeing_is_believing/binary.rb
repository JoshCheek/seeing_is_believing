require 'seeing_is_believing'
require 'seeing_is_believing/binary/parse_args'
require 'seeing_is_believing/binary/interpret_flags'
require 'seeing_is_believing/binary/annotate_every_line'
require 'seeing_is_believing/binary/annotate_xmpfilter_style'
require 'seeing_is_believing/binary/remove_annotations'
require 'timeout'

class SeeingIsBelieving
  module Binary
    SUCCESS_STATUS              = 0
    DISPLAYABLE_ERROR_STATUS    = 1 # e.g. there was an error, but the output is legit (we can display exceptions)
    NONDISPLAYABLE_ERROR_STATUS = 2 # e.g. an error like incorrect invocation or syntax that can't be displayed in the input program

    def self.call(argv, stdin, stdout, stderr)
      flags   = ParseArgs.call(argv)
      options = InterpretFlags.new(flags, stdin, stdout)

      if options.print_errors?
        stderr.puts options.errors.join("\n")
        return NONDISPLAYABLE_ERROR_STATUS
      end

      if options.print_help?  # TODO: Should this be first?
        stdout.puts options.help_screen
        return SUCCESS_STATUS
      end

      if options.print_version?
        stdout.puts SeeingIsBelieving::VERSION
        return SUCCESS_STATUS
      end

      if options.provided_filename_dne?
        stderr.puts "#{options.filename} does not exist!"
        return NONDISPLAYABLE_ERROR_STATUS
      end

      if options.print_cleaned?
        stdout.print RemoveAnnotations.call(options.prepared_body, true, options.markers)
        return SUCCESS_STATUS
      end

      syntax_error_notice = syntax_error_notice_for(options.body, options.shebang)
      if syntax_error_notice
        stderr.puts syntax_error_notice
        return NONDISPLAYABLE_ERROR_STATUS
      end

      results, program_timedout, unexpected_exception =
        evaluate_program(options.prepared_body, options.lib_options)

      if program_timedout
        stderr.puts "Timeout Error after #{options.timeout} seconds!"
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

      if options.result_as_json?
        require 'json'
        stdout.puts JSON.dump(result_as_data_structure(results))
        return SUCCESS_STATUS
      end

      # TODO: Annoying debugger stuff from annotators can move up to here
      # or maybe debugging goes to stderr, and we still print this anyway?
      stdout.print options.annotator.call(options.prepared_body,
                                          results,
                                          options.annotator_options)

      if options.inherit_exit_status?
        results.exitstatus
      elsif results.has_exception?
        DISPLAYABLE_ERROR_STATUS
      else
        SUCCESS_STATUS
      end
    end

    private

    def self.syntax_error_notice_for(body, shebang)
      out, err, syntax_status = Open3.capture3 shebang, '-c', stdin_data: body
      return err unless syntax_status.success?

      # The stdin_data may still be getting written when the pipe closes
      # This is because Ruby will stop reading from stdin if everything left is in the DATA segment, and the data segment is not referenced.
      # In this case, the Syntax is fine
      # https://bugs.ruby-lang.org/issues/9583
    rescue Errno::EPIPE
      return nil
    end

    def self.evaluate_program(body, options)
      return SeeingIsBelieving.call(body, options), nil, nil
    rescue Timeout::Error
      return nil, true, nil
    rescue Exception
      return nil, false, $!
    end

    def self.result_as_data_structure(results)
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
