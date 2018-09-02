class SeeingIsBelieving
  module Compatibility
  end
end

# Ruby 2.0.0 is soooooo painful >.<
# want to stop supporting this so bad!!
is_v2_0 = !String.instance_methods.include?(:scrub)

is_v2_0 && begin
  old_verbose, $VERBOSE = $VERBOSE, nil
  module SeeingIsBelieving::Compatibility
    refine String do
      def scrub(char=nil, &block)
        char && block = lambda { |c| char }
        each_char.inject("") do |new_str, char|
          if char.valid_encoding?
            new_str << char
          else
            new_str << block.call(char)
          end
        end
      end
    end
  end
ensure
  $VERBOSE = old_verbose
end
