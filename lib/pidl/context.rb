require 'thread'
require 'lazy'

module Pidl

  # Provide shared context to DSL entities by
  # exposing a shared key/value set.
  class Context

    attr_reader :params

    # Create a new, empty key/value set
    def initialize(flags = nil)
      flags ||= {}
      @params = flags[:params] || []
      @context = {}
      @mutex = Mutex.new
    end

    # Store the given key/from the
    # schema hash, or raise a
    # KeyError if it cannot be found.
    def set key, value
      @mutex.synchronize {
        @context[key] = value
      }
    end

    # Retrieve the given key from the
    # context hash, or raise a
    # KeyError if it cannot be found.
    def get key
      return Lazy::promise do
        @mutex.synchronize do
          if @context[key].nil?
            raise KeyError.new("Key #{key} not found in context")
          end
          @context[key]
        end
      end
    end

    # Get a hash containing all keys
    # and values of the context
    def all
      @context
    end

  end

end
