require_relative '../../lib/seeing_is_believing/version'

require 'haiti'

module SiBHelpers
  def method_result(name)
    @result = def __some_method__; end
    if :__some_method__ == @result
      name.inspect
    elsif nil == @result
      nil.inspect
    else
      raise "huh? #{@result.inspect}"
    end
  end
end

World SiBHelpers

Haiti.configure do |config|
  config.proving_grounds_dir = File.realdirpath  '../../proving_grounds', __dir__
  config.bin_dir             = File.realpath     '../../bin',             __dir__
end


Then 'stdout is exactly:' do |code|
  expect(@last_executed.stdout).to eq eval_curlies(code)
end

Then 'stdout is exactly "$code"' do |code|
  expect(@last_executed.stdout).to eq eval_curlies(code)
end

Then 'stdout is the JSON:' do |json|
  require 'json'
  expected = JSON.parse(json)
  actual   = JSON.parse(@last_executed.stdout)
  expect(actual).to eq expected
end

Given %q(the file '$filename' '$body') do |filename, body|
  Haiti::CommandLineHelpers.write_file filename, eval_curlies(body)
end
