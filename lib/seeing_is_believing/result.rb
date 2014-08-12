require 'seeing_is_believing/line'
require 'seeing_is_believing/has_exception'

class SeeingIsBelieving
  class Result
    include HasException
    include Enumerable

    def self.from_primitive(primitive)
      new.from_primitive(primitive)
    end

    def from_primitive(primitive)
      self.exitstatus = primitive['exitstatus']
      self.stdout     = primitive['stdout']
      self.stderr     = primitive['stderr']
      self.bug_in_sib = primitive['bug_in_sib']
      self.exception  = RecordedException.from_primitive primitive['exception']
      primitive['results'].each do |line_number, primitive_line|
        results_for(line_number.to_i).from_primitive(primitive_line)
      end
      self
    end

    def to_primitive
      primitive = {
        'exitstatus' => exitstatus,
        'stdout'     => stdout,
        'stderr'     => stderr,
        'bug_in_sib' => bug_in_sib,
        'exception'  => (exception && exception.to_primitive),
      }
      primitive['results'] = results.each_with_object({}) do |(line_number, line), r|
        r[line_number] = line.to_primitive
      end
      primitive
    end


    attr_accessor :stdout, :stderr, :exitstatus, :bug_in_sib, :number_of_captures

    alias bug_in_sib? bug_in_sib

    def has_stdout?
      stdout && !stdout.empty?
    end

    def has_stderr?
      stderr && !stderr.empty?
    end

    def record_result(line_number, value)
      results_for(line_number).record_result(value)
      value
    end

    def record_exception(line_number, exception)
      recorded_exception = RecordedException.new exception.class.name,
                                                 exception.message,
                                                 exception.backtrace
      self.exception = recorded_exception
      results_for(line_number).exception = recorded_exception
    end

    def [](line_number)
      results_for(line_number)
    end

    def each(&block)
      max = results.keys.max || 1
      (1..max).each { |line_number| block.call self[line_number] }
    end

    def each_with_line_number(&block)
      return to_enum :each_with_line_number unless block
      max = results.keys.max || 1
      (1..max).each { |line_number| block.call line_number, results_for(line_number) }
    end

    def inspect
      results
      variables = instance_variables.map do |name|
        value = instance_variable_get(name)
        inspected = if name.to_s == '@results'
          "{#{value.sort_by(&:first).map { |k, v| "#{k.inspect}=>#{v.inspect}"}.join(",\n            ")}}"
        else
          value.inspect
        end
        "#{name}=#{inspected}"
      end
      "#<SIB::Result #{variables.join "\n  "}>"
    end

    def number_of_captures
      @number_of_captures || Float::INFINITY
    end

    private

    def results_for(line_number)
      results[line_number] ||= Line.new([], number_of_captures)
    end

    def results
      @results ||= Hash.new
    end
  end
end
