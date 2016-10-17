class SeeingIsBelieving
  module Binary
    class InterlineAlign
      def initialize(results)
        @results        = results
        @format_strings = {}
      end

      def call(lineno, results)
        format_string_for_line(lineno) % results
      end

      private

      attr_accessor :results

      def format_string_for_line(lineno)
        group = groups_with_same_number_of_results(@results)[lineno]
        format_string_for(results, group, lineno)
      end

      def groups_with_same_number_of_results(results)
        @grouped_by_no_results ||= begin
          length = 0
          groups = 1.upto(results.num_lines)
                    .slice_before { |num|
                      new_length = results[num].length
                      slice      = length != new_length
                      length     = new_length
                      slice
                    }.to_a

          groups.each_with_object Hash.new do |group, lineno_to_group|
            group.each { |lineno| lineno_to_group[lineno] = group }
          end
        end
      end

      def format_string_for(results, group, lineno)
        @format_strings[lineno] ||= begin
          index = group.index lineno
          group
            .map { |lineno| results[lineno] }
            .transpose
            .map { |col|
              lengths = col.map(&:length)
              max     = lengths.max
              crnt    = lengths[index]
              "%-#{crnt}s,#{" "*(max-crnt)} "
            }
            .join
            .sub(/, *$/, "")
        end
      end
    end
  end
end
