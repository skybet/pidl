module Pidl
  # Loaded pidl gem
  GEM=Gem.loaded_specs['pidl']

  # Current Pidl version
  VERSION=GEM.nil? ? '[dev]' : GEM.version.to_s
end
