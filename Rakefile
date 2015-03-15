desc 'Have Bundler setup a standalone environment -- run tests in this, b/c its faster and safer'
file :bundle do
  # Running without rubygems  # http://myronmars.to/n/dev-blog/2012/03/faster-test-boot-times-with-bundler-standalone
  sh 'bundle install --standalone --binstubs bundle/bin'
  sh 'ruby --disable-gems -S bundle/bin/rspec'
end


desc 'Run specs'
task spec: :bundle do
  sh 'ruby', '--disable-gem',
             '-S', 'bundle/bin/rspec', # rspec
             '--colour',
             '--fail-fast',
             '--format', 'documentation'
end

desc 'Run cukes'
task cuke: :bundle do
  sh 'ruby', '--disable-gem',
             '-S', 'bundle/bin/cucumber', # cucumber
             '--tags', '~@not-implemented'
end

desc 'Run all specs and cukes'
task default: [:spec, :cuke]
