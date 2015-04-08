desc 'Have Bundler setup a standalone environment -- run tests in this, b/c its faster and safer'
task :build do
  # Running without rubygems  # http://myronmars.to/n/dev-blog/2012/03/faster-test-boot-times-with-bundler-standalone
  sh 'bundle install --standalone --binstubs bundle/bin'
end

desc 'Remove generated and irrelevant files'
task :clean do
  rm_rf [
    'bundle',
    '.bundle',
    'Gemfile.lock',
    'proving_grounds',
    *Dir['*.gem'],
  ]
end


file :bundle do
  $stderr.puts "\e[31mLooks like the gems aren\'t installed, run `rake build` to install them\e[39m"
  exit 1
end

desc 'Run specs'
task spec: :bundle do
  sh 'ruby', '--disable-gem', '-S', 'bundle/bin/rspec'
end

desc 'Run cukes'
task cuke: :bundle do
  sh 'ruby', '--disable-gem', '-S',
     'bundle/bin/cucumber', '--tags', '~@not-implemented'
end

desc 'Run all specs and cukes'
task default: [:spec, :cuke]

desc 'Install dependencies and run tests (mainly for Travis CI)'
task ci: [:build, :spec, :cuke]
