require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'rdoc/task'
require 'gem_version'

task :default => [:spec]

RSpec::Core::RakeTask.new do |task|
  task.rspec_opts = ['--color']
end

RDoc::Task.new do |rdoc|
  #rdoc.main = 'README.rdoc'
  rdoc.rdoc_files.include('lib/  *.rb', 'lib/pidl/  *.rb')
  rdoc.rdoc_dir = 'doc'
end

