# WARNING: DO NOT REQUIRE THIS FILE, IT WILL FUCK YOU UP!!!!!!

require 'seeing_is_believing/result'

require 'yaml'

# require 'stringio'
# real_stdout = STDOUT
# real_stderr = STDERR
# STDOUT = $stdout = StringIO.new
# STDERR = $stderr = StriongIO.new

$seeing_is_believing_current_result = SeeingIsBelieving::Result.new

at_exit do
  $stdout.write YAML.dump $seeing_is_believing_current_result
end
