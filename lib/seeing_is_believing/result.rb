require 'seeing_is_believing/line'
require 'seeing_is_believing/has_exception'
require 'seeing_is_believing/tracks_line_numbers_seen'

class SeeingIsBelieving
  class Result
    include HasException
    include TracksLineNumbersSeen
    include Enumerable

    attr_accessor :stdout, :stderr, :exitstatus, :bug_in_sib

    alias bug_in_sib? bug_in_sib

    def has_stdout?
      stdout && !stdout.empty?
    end

    def has_stderr?
      stderr && !stderr.empty?
    end

    def initialize
      @min_line_number = @max_line_number = 1
    end

    def record_result(line_number, value)
      track_line_number line_number
      results_for(line_number) << value.inspect
      value
    end

    def record_exception(line_number, exception)
      recorded_exception = RecordedException.new exception.class.name,
                                                 exception.message,
                                                 exception.backtrace
      self.exception = recorded_exception
      track_line_number line_number
      results_for(line_number).exception = recorded_exception
    end

    def [](line_number)
      results_for(line_number)
    end

    def each(&block)
      (min_line_number..max_line_number).each { |line_number| block.call self[line_number] }
    end

    def inspect
      results
      "#<SIB::Result #{
        instance_variables.map { |name| "#{name}=#{instance_variable_get(name).inspect}" }.join("\n  ")
      }>"
    end

    private

    def results_for(line_number)
      results[line_number] ||= Line.new
    end

    def results
      @results ||= Hash.new
    end
  end
end
