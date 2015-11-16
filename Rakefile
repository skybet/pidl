require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'rdoc/task'

task :default => [:spec]

RSpec::Core::RakeTask.new do |task|
  task.rspec_opts = ['--color']
end

RDoc::Task.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_files.include('README.md','lib/pidl.rb', 'lib/pidl/*.rb')
  rdoc.rdoc_dir = 'doc'
end

