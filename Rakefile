desc 'run specs'
task :spec do
  sh 'rspec -t ~not_implemented -cf d --fail-fast'
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

desc 'Run work in progress specs and cukes'
task wip: ['spec:wip', 'cuke:wip']

desc 'Run all specs and cukes'
task default: [:spec, :cuke]
