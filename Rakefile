desc 'Have Bundler setup a standalone environment -- run tests in this, b/c its faster and safer'
task :install do
  `which bundle`
  unless $?.success?
    sh 'gem', 'install', 'bundler'
  end

  unless Dir.exist? 'bundle'
    # Running without rubygems  # http://myronmars.to/n/dev-blog/2012/03/faster-test-boot-times-with-bundler-standalone
    sh 'bundle', 'install', '--standalone', '--binstubs', 'bundle/bin'
  end
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

directory 'bundle' do
  $stderr.puts "\e[31mLooks like the gems aren\'t installed, run `rake install` to install them\e[39m"
  exit 1
end

def require_paths
  require 'bundler'
  requrable_paths = Bundler.load.specs.flat_map { |spec|
    spec.require_paths.map do |path|
      File.join(spec.full_gem_path, path)
    end
  }.flat_map { |p| ['-I', p ] }
end

desc 'Run specs'
task spec: :bundle do
  sh 'ruby', '--disable-gem', *require_paths, '-S', 'bundle/bin/mrspec'
end

desc 'Run cukes'
task cuke: :bundle do
  require 'bundler'
  sh 'ruby', '--disable-gem',
             *require_paths,
             '-S', 'bundle/bin/cucumber',
             '--tags', '~@not-implemented',
             '--tags', "~@not-#{RUBY_VERSION}"
end

desc 'Run all specs and cukes'
task default: [:spec, :cuke]

desc 'Install dependencies and run tests (mainly for Travis CI)'
task ci: [:install, :spec, :cuke]
