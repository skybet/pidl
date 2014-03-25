require 'logger'

module Pidl
  # A simple logger used by default that does not actually send log messages
  # anywhere.
  class FakeLogger < Logger # :nodoc:
    def initialize(*args)
    end
    def add(*args, &block)
    end
  end
end
