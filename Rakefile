desc 'Have Bundler setup a standalone environment -- run tests in this, b/c its faster and safer'
task :install do
  # Running without rubygems http://myronmars.to/n/dev-blog/2012/03/faster-test-boot-times-with-bundler-standalone
  which("bundle")     or sh 'gem', 'install', 'bundler', '--no-ri', '--no-rdoc'
  Dir.exist? 'bundle' or sh 'bundle', 'install', '--standalone', '--binstubs', 'bundle/bin'
end

desc 'Remove generated and irrelevant files'
task :clean do
  rm_rf %w[bundle .bundle Gemfile.lock proving_grounds tags] + Dir['*.gem']
end

directory 'bundle' do
  $stderr.puts "\e[31mLooks like the gems aren\'t installed, run `rake install` to install them\e[39m"
  exit 1
end

def require_paths
  require 'bundler'
  Bundler.load.specs.flat_map do |spec|
    spec.require_paths
        .map { |path| File.join spec.full_gem_path, path }
        .flat_map { |p| ['-I', p] }
  end
end

desc 'Print the require paths for arbitrary binary execution'
task :require_paths, [:delimiter] => :bundle do |delimiter: ' '|
  puts require_paths.join(delimiter)
end

desc 'Run specs'
task spec: :bundle do
  sh 'ruby', '--disable-gem', *require_paths, '-S', 'bundle/bin/rspec', '--fail-fast'
end

desc 'Run cukes'
task cuke: :bundle do
  require 'bundler'
  platform_filter = Gem.win_platform? ? %W[--tags ~@not-windows] : []
  ruby_version_without_patchlevel = RUBY_VERSION[/^\d+\.\d+/]
  sh 'ruby', '--disable-gem',
     *require_paths,
     '-S', 'bundle/bin/cucumber',
     '--tags', '~@not-implemented',
     '--tags', "~@not-#{RUBY_VERSION}",
     '--tags', "~@not-#{ruby_version_without_patchlevel}",
      *platform_filter
end

desc 'Generate tags for quick navigation'
task tags: :bundle do
  excludes = %w[tmp tmpgem bundle proving_grounds].map { |dir| "--exclude=#{dir}" }
  sh 'ruby', '--disable-gem',
     *require_paths,
     '-S', 'bundle/bin/ripper-tags',
     '-R', *excludes
end
task ctags: :tags # an alias


desc 'Run all specs and cukes'
task default: [:spec, :cuke]

desc 'Install dependencies and run tests (mainly for Travis CI)'
task ci: [:spec, :cuke]

def self.which(exe)
  dirs = ENV["PATH"].split(File::PATH_SEPARATOR)
  exts = [""]
  exts.concat(ENV["PathExt"].to_s.split(File::PATH_SEPARATOR))
  candidates = dirs.product(exts) { |dir, ext| File.join(dir, exe + ext) }
  exe_path = candidates.find { |c| File.executable?(c) }
end
