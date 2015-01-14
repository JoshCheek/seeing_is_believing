require 'seeing_is_believing/strict_hash'

class SeeingIsBelieving
  module Binary
    class Marker < StrictHash
      def self.to_regex(string)
        return string if string.kind_of? Regexp
        flag_to_bit = {
          'i' => 0b001,
          'x' => 0b010,
          'm' => 0b100
        }
        string =~ %r{\A/(.*)/([mxi]*)\Z}
        body  = $1 || string
        flags = ($2 || "").each_char.inject(0) { |bits, flag| bits | flag_to_bit[flag] }
        Regexp.new body, flags
      end

      attribute :text  # text, e.g. "# => "
      attribute :regex # identify text in a comment, e.g. /^# => /
      def []=(key, value)
        value = Marker.to_regex(value) if key == :regex
        super key, value
      end
    end
  end
end
