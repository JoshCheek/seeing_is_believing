# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!


require 'yaml'
require 'stringio'
real_stdout = STDOUT
real_stderr = STDERR
STDOUT = $stdout = fake_stdout = StringIO.new
STDERR = $stderr = fake_stderr = StringIO.new

require 'seeing_is_believing/result'
$seeing_is_believing_current_result = SeeingIsBelieving::Result.new

at_exit do
  $seeing_is_believing_current_result.stdout = fake_stdout.string
  $seeing_is_believing_current_result.stderr = fake_stderr.string

  real_stdout.write YAML.dump $seeing_is_believing_current_result
end
