Gem::Specification.new do |s|
  s.name         = 'pidl'
  s.version      = File.read('VERSION')
  s.summary      = 'PIpeline Definition Language'

  s.description  = 'DSL for orchestration of parallel dependent pipelines of tasks'
  s.license      = 'MIT'
  s.homepage     = 'https://github.com/skybet/pidl'
  s.email        = 'careersinleeds@skybettingandgaming.com'

  s.authors      = ['Craig Andrews', 'Alice Kaerast', 'Andrea McLaren', 'Darrell Taylor','Thomas Scott',
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
