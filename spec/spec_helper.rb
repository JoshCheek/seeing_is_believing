require 'sib_spec_helpers/version'

module SibSpecHelpers
  def pending!(message="Not yet implemented")
    pending message
    raise message
  end

  def ruby_version
    Version.new RUBY_VERSION
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
