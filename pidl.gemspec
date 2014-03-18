Gem::Specification.new do |s|
  s.name        = 'pidl'
  s.version     = '0.0.0'
  s.date        = '2014-03-18'
  s.summary     = "PIpeline Definition Language"
  s.description = "DSL for orchestration of parallel dependent pipelines of tasks"
  s.authors     = ["Craig Andrews"]
  s.email       = 'craig.andrews@bskyb.com'
  s.files       = [
    "lib/base.rb",
    "lib/context.rb",
    "lib/pidl.rb",
    "lib/pipeline.rb",
    "lib/task.rb",
    "lib/action.rb",
    "lib/fakelogger.rb"
  ]
  s.homepage    =
    'http://rubygems.org/gems/pidl'
  s.license       = 'MIT'
end
