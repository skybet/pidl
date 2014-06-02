module Pidl
  # Current Pidl version
  GEM=Gem.loaded_specs['pidl']
  VERSION=GEM.nil? ? '[dev]' : GEM.version.to_s
end
