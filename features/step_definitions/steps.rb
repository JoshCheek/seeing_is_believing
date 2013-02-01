Given 'the file "$filename":' do |filename, body|
  CommandLineHelpers.write_file filename, body
end

Given 'I have the stdin content "$content"' do |content|
  @stdin_data = content
end

When 'I run "$command"' do |command|
  @last_executed = CommandLineHelpers.execute command, @stdin_data
end

Then /^(stderr|stdout) is:$/ do |stream_name, output|
  @last_executed.send(stream_name).chomp.should == eval_curlies(output)
end

Then /^(stderr|stdout) is "(.*?)"$/ do |stream_name, output|
  @last_executed.send(stream_name).chomp.should == eval_curlies(output)
end

Then 'the exit status is $status' do |status|
  @last_executed.exitstatus.to_s.should == status
end

Then /^(stderr|stdout) is empty$/ do |stream_name|
  @last_executed.send(stream_name).should == ''
end
