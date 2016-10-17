require 'seeing_is_believing/hash_struct'

class SeeingIsBelieving
  module Binary
    class Markers < HashStruct
      attribute(:value)     { Marker.new prefix: '# => ', regex: '^#\s*=>\s*' }
      attribute(:exception) { Marker.new prefix: '# ~> ', regex: '^#\s*~>\s*' }
      attribute(:stdout)    { Marker.new prefix: '# >> ', regex: '^#\s*>>\s*' }
      attribute(:stderr)    { Marker.new prefix: '# !> ', regex: '^#\s*!>\s*' }
    end


    class Marker < HashStruct
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

      attribute :prefix  # e.g. "# => "
      attribute :regex   # identify prefix in a comment, e.g. /^# => /

      def []=(key, value)
        value = Marker.to_regex(value) if key == :regex
        super key, value
      end
    end


    class AnnotatorOptions < HashStruct
      attribute(:alignment_strategy) { AlignChunk }
      attribute(:markers)            { Markers.new }
      attribute(:max_line_length)    { Float::INFINITY }
      attribute(:max_result_length)  { Float::INFINITY }
      predicate(:interline_align)    { true }
    end


    class ErrorMessage < HashStruct.for(:explanation)
      def to_s
        "Error: #{explanation}"
      end
    end

    class SyntaxErrorMessage < ErrorMessage.for(:line_number, :filename)
      def to_s
        "Syntax Error: #{filename}:#{line_number}\n#{explanation}\n"
      end
    end
  end
end
