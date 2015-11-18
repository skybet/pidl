# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'rubygems'

Gem::Specification.new do |s|
  s.name          = 'pidl'
  s.version       = ENV['VERSION_NUMBER'] || "0.1.#{ENV['BUILD_NUMBER'] || 'dev'}"
  s.summary       = 'PIpeline Definition Language'
  s.description   = 'DSL for orchestration of parallel dependent pipelines of tasks'
  s.authors       = ['Craig Andrews', 'Alice Kaerast', 'Andrea McLaren', 'Darrell Taylor','Josh Mitchell']
  s.email         = 'DL-SkyBetDataWarehouse@skybettingandgaming.com'
  s.files         = `git ls-files`.split($/)
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]
  s.homepage      = 'http://rubygems.org/gems/pidl'
  s.license       = 'MIT'

  s.add_development_dependency 'git'
  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec_junit_formatter', '~> 0.2.3'
  s.add_development_dependency 'simplecov', '~> 0.10.0'
  s.add_development_dependency 'simplecov-rcov', '~> 0.2.3'
  s.add_dependency 'lazy'
end
