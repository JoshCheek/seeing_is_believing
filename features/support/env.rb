require_relative '../../lib/seeing_is_believing/version'

require 'haiti'
# A lot of the stuff in this file should get moved into haiti

module Haiti
  module CommandLineHelpers
    # overwriting this method while trying to get windows support working,
    # it looks like the underlying shell is treating the commands differently
    # probably on Unix it invoked `sh` and did shady shit with splitting a string into an array on whitespace
    # and on Windows (powershell?) it expected an actual array of strings
    require 'shellwords'
    def execute(command_string, stdin_data, env_vars)
      stdin_data ||= ''
      env_vars   ||= {}
      in_proving_grounds do
        with_bin_in_path do
          Invocation.new *Open3.capture3(env_vars, command_string, stdin_data: stdin_data)
        end
      end
    end

    def execute_pipeline(command_strings, stdin_data, env_vars)
      stdin_data ||= ''
      env_vars   ||= {}
      in_proving_grounds do
        with_bin_in_path do
          ioin, ioout, pids = Open3.pipeline_rw *command_strings.map { |cmd| [env_vars, cmd] }
          ioin.print stdin_data
          ioin.close
          stderr = "" # uh... how do I record it for real?
          Invocation.new ioout.read, stderr, pids.last.value
        end
      end
    end

    def with_bin_in_path
      original_path = ENV['PATH']
      dirs          = ENV["PATH"].split(File::PATH_SEPARATOR)
      ENV['PATH']   = [config.bin_dir, *dirs].join(File::PATH_SEPARATOR)
      yield
    ensure
      ENV['PATH'] = original_path
    end
  end
end

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
  lib_root                   = File.join __dir__, '..', '..'
  config.proving_grounds_dir = File.expand_path 'proving_grounds', lib_root
  config.bin_dir             = File.expand_path 'bin',             lib_root
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

Given /^I run the pipeline "([^"]*)"(?: *\| *"([^"]*)")*$/ do |*commands|
  @last_executed = Haiti::CommandLineHelpers.execute_pipeline(
    commands,
    @stdin_data,
    @env_vars_to_set
  )
end

Given(/^the binary file "([^"]*)" "([^"]*)"$/) do |filename, body|
  Haiti::CommandLineHelpers.in_proving_grounds do
    FileUtils.mkdir_p File.dirname filename
    File.open(filename, 'wb') { |file| file.write body }
  end
end
