class SeeingIsBelieving
  class Result
    include Enumerable
    RecordedException = Struct.new :line_number, :class_name, :message, :backtrace

    attr_accessor :stdout, :stderr, :exitstatus, :max_line_captures, :exception, :num_lines, :sib_version, :ruby_version, :filename, :timeout_seconds

    def initialize
      self.stdout = ''
      self.stderr = ''
    end

    alias has_exception? exception

    def has_stdout?
      stdout && !stdout.empty?
    end

    def has_stderr?
      stderr && !stderr.empty?
    end

    def timeout?
      !!timeout_seconds
    end

    def record_result(type, line_number, value)
      results_for(line_number, type) << value
      value
    end

    def record_exception(line_number, exception_class, exception_message, exception_backtrace)
      self.exception = RecordedException.new line_number, exception_class, exception_message, exception_backtrace
    end

    def [](line_number, type=:inspect)
      results_for(line_number, type)
    end

    def each(&block)
      return to_enum :each unless block
      (1..num_lines).each { |line_number| block.call self[line_number] }
    end

    def max_line_captures
      @max_line_captures || Float::INFINITY
    end

    def as_json
      ex = has_exception? && {
        line_number_in_this_file: exception.line_number,
        class_name:               exception.class_name,
        message:                  exception.message,
        backtrace:                exception.backtrace,
      }

      { stdout:     stdout,
        stderr:     stderr,
        exitstatus: exitstatus,
        exception:  ex,
        lines:      each.with_object(Hash.new)
                        .with_index(1) { |(result, hash), line_number| hash[line_number] = result },
      }
    end

    private

    def results_for(line_number, type)
      line_results = (results[line_number] ||= Hash.new { |h, k| h[k] = [] })
      line_results[type]
    end

    def results
      @results ||= Hash.new
    end
  end
end
