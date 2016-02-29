require 'rake/version_task'
Rake::VersionTask.new
require 'rubygems'
require 'rubygems/package_task'
require 'rdoc/task'
require 'rspec/core/rake_task'
require 'bundler/audit/task'

spec = Gem::Specification.new do |s|
  s.name         = 'pidl'
  s.version      = Version.current or '0.0.0'
  s.summary      = 'PIpeline Definition Language'

  s.description  = 'DSL for orchestration of parallel dependent pipelines of tasks'
  s.license      = 'MIT'
  s.homepage     = 'https://github.com/skybet/pidl'
  s.email        = 'careersinleeds@skybettingandgaming.com'

  s.authors      = ['Craig Andrews', 'Alice Kaerast', 'Andrea McLaren', 'Darrell Taylor','Thomas Scott','Josh Mitchell']
  s.files        = Dir['[A-Z]*', 'lib/**/*.rb', 'spec/**/*']
  s.rdoc_options = %w{ --main README.md }

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec_junit_formatter', '~> 0.2.3'
  s.add_development_dependency 'simplecov', '~> 0.10.0'
  s.add_development_dependency 'simplecov-rcov', '~> 0.2.3'
  s.add_development_dependency 'version'

  s.add_dependency 'lazy'
end

Gem::PackageTask.new(spec) do |gem|
  gem.need_zip = true
  gem.need_tar = true
end

Rake::RDocTask.new do |doc|
  doc.title    = "pidl #{Version.current}"
  doc.rdoc_dir = 'doc'
  doc.main     = 'README.md'
  doc.rdoc_files.include('README.md','lib/**/*.rb')
end

RSpec::Core::RakeTask.new(:spec, [:output, :verbose]) do |task, args|
  task.pattern = ['spec/**/*_spec.rb', 'spec/**/**/*_spec.rb']
  task.rspec_opts = ['--format RspecJunitFormatter --out spec/reports/junit.xml'] if args[:output] == 'junit' || args[:output] == 'coverage'
  task.verbose = false if args[:verbose] == 'quiet'
  ENV['COVERAGE']='true' if args[:output] == 'coverage'
end

Bundler::Audit::Task.new

task :default => [:spec]
