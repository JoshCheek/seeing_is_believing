Given('the file "$filename" "$body"')        { |filename, body|       CommandLineHelpers.write_file filename, body }
Given('the file "$filename":')               { |filename, body|       CommandLineHelpers.write_file filename, body }
Given('I have the stdin content "$content"') { |content|              @stdin_data = content }
Given('I have the stdin content:')           { |content|              @stdin_data = content }
When('I run "$command"')                     { |command|              @last_executed = CommandLineHelpers.execute command, @stdin_data }
When("I run '$command'")                     { |command|              @last_executed = CommandLineHelpers.execute command, @stdin_data }
Then(/^(stderr|stdout) is:$/)                { |stream_name, output|  @last_executed.send(stream_name).chomp.should == output }
Then(/^(stderr|stdout) is ["'](.*?)["']$/)   { |stream_name, output|  @last_executed.send(stream_name).chomp.should == output }
Then(/^(stderr|stdout) is empty$/)           { |stream_name|          @last_executed.send(stream_name).should == '' }
Then(/^(stderr|stdout) includes "([^"]*)"$/) { |stream_name, content| @last_executed.send(stream_name).should include content }
Then('the exit status is $status')           { |status|               @last_executed.exitstatus.to_s.should == status }
