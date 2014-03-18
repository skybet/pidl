require 'thread'
require 'lazy'

module Pidl

  # Provide shared context to DSL entities by
  # exposing config, schema and a shared
  # key/value store.
  class Context

    # Create a new, empty key/value store
    # and accept the config and schema
    # hashes.
    def initialize(config, schema)
      @config = config
      @schema = schema
      @context = {}
      @mutex = Mutex.new
    end

    # Retrieve the given key from the
    # config hash, or raise a
    # KeyError if it cannot be found.
    def config key
      if @config[key].nil?
        raise KeyError.new("Key #{key} not found in config")
      end
      @config[key]
    end

    # Retrieve the given key from the
    # schema hash, or raise a
    # KeyError if it cannot be found.
    def schema key
      if @schema[key].nil?
        raise KeyError.new("Key #{key} not found in schema")
      end
      @schema[key]
    end

    # Store the given key/from the
    # schema hash, or raise a
    # KeyError if it cannot be found.
    def store key, value
      @mutex.synchronize {
        @context[key] = value
      }
    end

    # Retrieve the given key from the
    # context hash, or raise a
    # KeyError if it cannot be found.
    def retrieve key
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
