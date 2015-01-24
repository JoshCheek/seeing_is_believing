simplecov_file = File.expand_path 'spec/simplecov'
ENV['RUBYOPT'] = "-r#{simplecov_file}"

desc 'run specs'
task :spec do
  sh 'rspec -cf d --fail-fast'
end

desc 'run cukes'
task :cuke do
  sh 'cucumber -t ~@not-implemented -t ~@wip'
end

namespace :cuke do
  desc 'Run work in progress cukes'
  task :wip do
    sh 'cucumber -t @wip'
  end
end

namespace :spec do
  desc 'Run work in progress specs'
  task :wip do
    sh 'rspec -t wip'
  end
end

desc 'Show most recent test run\'s code coverage'
task :coverage do
  require 'simplecov'
  require 'simplecov-html'
  SimpleCov.result.format!
end

task :reset_coverage do
  rm_r 'coverage'
end

desc 'Run work in progress specs and cukes'
task wip: ['spec:wip', 'cuke:wip']

desc 'Run all specs and cukes'
task default: [:reset_coverage, :spec, :cuke, :coverage]
