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

task :bump do
  GemVersion.increment_version
  File.open("lib/pidl/version.rb", 'w') do |f|
    f.write <<eos
module Pidl
  # Current Pidl version
  VERSION="#{GemVersion.next_version}"
end
eos
  end
  GemVersion.commit_and_push do |git|
    git.add "lib/pidl/version.rb"
  end
end

