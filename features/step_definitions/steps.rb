Given 'the file "$filename":' do |filename, body|
  CommandLineHelpers.write_file filename, body
end

When 'I run "$command"' do |command|
  @last_executed = CommandLineHelpers.execute command
end

Then /^(stderr|stdout) is:$/ do |stream_name, output|
  @last_executed.send(stream_name).chomp.should == output
end

Then /^(stderr|stdout) is "(.*?)"$/ do |stream_name, output|
  @last_executed.send(stream_name).chomp.should == output
end

Then 'the exit status is $status' do |status|
  @last_executed.exitstatus.to_s.should == status
end

Then /^(stderr|stdout) is empty$/ do |stream_name|
  @last_executed.send(stream_name).should == ''
end
