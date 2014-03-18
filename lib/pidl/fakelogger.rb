require 'logger'

module Pidl
  class FakeLogger < Logger
    def initialize(*args)
    end
    def add(*args, &block)
    end
  end
end
