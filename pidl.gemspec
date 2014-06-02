# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rake'
require 'gem_version'

Gem::Specification.new do |s|
  s.name        = 'pidl'
  s.version     = "0.1.#{ENV['BUILD_NUMBER'] || 'dev'}"
  s.date        = '2014-03-18'
  s.summary     = 'PIpeline Definition Language'
  s.description = 'DSL for orchestration of parallel dependent pipelines of tasks'
  s.authors     = ['Craig Andrews']
  s.email       = 'craig.andrews@bskyb.com'
  s.files         = `git ls-files`.split($/)
  #s.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]
  s.homepage    =
    'http://rubygems.org/gems/pidl'
  s.license       = 'MIT'
  #s.platform = 'java'

  s.add_development_dependency 'git'
  s.add_development_dependency 'gem_spec'
  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'guard'
  s.add_development_dependency 'guard-rspec'

  s.add_dependency 'lazy'
end
