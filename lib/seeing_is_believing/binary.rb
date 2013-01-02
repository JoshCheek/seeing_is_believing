require 'seeing_is_believing'

class SeeingIsBelieving
  class Binary
    def initialize(argv, stdout, stderr)
      self.argv   = argv
      self.stdout = stdout
      self.stderr = stderr
    end

    def call
      argv.each do |filename|
        body = File.read(filename)
        write_file body,
                   max_line_length_in(body) + 2,
                   SeeingIsBelieving.new(body).call
      end
      0
    end

    private

    def write_file(body, line_length, results)
      body.each_line.with_index 1 do |line, index|
        write_line line.chomp, results[index], line_length
      end
    end

    def write_line(line, results, line_length)
      if results.any?
        stdout.printf "%-#{line_length}s# => %s\n", line, results.join(', ')
      else
        stdout.puts line
      end
    end

    attr_accessor :argv, :stdout, :stderr

    def max_line_length_in(string)
      string.each_line.map(&:chomp).map(&:length).max
    end
  end
end
