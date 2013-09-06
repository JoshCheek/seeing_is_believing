require_relative '../../lib/seeing_is_believing/version'

require 'haiti'
Haiti.configure do |config|
  config.proving_grounds_dir = File.expand_path '../../../proving_grounds', __FILE__
  config.bin_dir             = File.expand_path '../../../bin',             __FILE__
end


Then 'stdout is exactly:' do |code|
  @last_executed.stdout.should == eval_curlies(code)
end

Then 'stdout is the JSON:' do |json|
  expected = JSON.parse(json)
  actual   = JSON.parse(@last_executed.stdout)
  actual.should == expected
end
