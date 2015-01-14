module SibSpecHelpers
  def pending!(message="Not yet implemented")
    pending message
    raise message
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.include SibSpecHelpers
end
