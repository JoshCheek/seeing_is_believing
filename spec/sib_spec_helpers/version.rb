module SibSpecHelpers
  class Version
    attr_reader :segments
    include Comparable
    def initialize(version_string)
      @segments = version_string.scan(/\d+/).map(&:to_i)
    end
    def <=>(other)
      other = Version.new other unless other.kind_of? Version
      segments.zip(other.segments).each do |ours, theirs|
        return  1 if theirs.nil? || theirs < ours
        return -1 if ours < theirs
      end
      segments.length <=> other.segments.length
    end
  end
end
