module SibSpecHelpers
  def pending!(message="Not yet implemented")
    pending message
    raise message
  end

  def ruby_version
    Version.new RUBY_VERSION
  end


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

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.include SibSpecHelpers
  c.filter_run_excluding :not_implemented

  if RSpec::Support::OS.windows? || RSpec::Support::Ruby.jruby?
    c.before(needs_fork: true) { skip 'Fork is not available on this system' }
  end

  if RSpec::Support::OS.windows?
    c.before(windows: false) { skip "This either doesn't work or I can't figure out how to test it on Windows" }
  end
end
