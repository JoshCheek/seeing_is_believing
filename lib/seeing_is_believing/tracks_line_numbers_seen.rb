class SeeingIsBelieving
  module TracksLineNumbersSeen
    INITIAL_LINE_NUMBER = 1 # uhm, should this change to 0?

    def track_line_number(line_number)
      @min_line_number = line_number if line_number < min_line_number
      @max_line_number = line_number if line_number > max_line_number
    end

    def min_line_number
      @min_line_number || INITIAL_LINE_NUMBER
    end

    def max_line_number
      @max_line_number || INITIAL_LINE_NUMBER
    end
  end
end
