require 'thread'
require 'lazy'

module Pidl

  # Provide shared context to DSL entities by
  # exposing a shared key/value set.
  class Context

    # Create a new, empty key/value set
    def initialize(flags = nil)
      flags ||= {}
      @context = {}
      @mutex = Mutex.new
      @logger = flags[:logger] || FakeLogger.new
      flags.delete :logger

      # Create custom accessors for the flags
      flags.each { |name, value|
        create_accessor_method name, value
      }
    end

    # Store the given key/from the
    # schema hash, or raise a
    # KeyError if it cannot be found.
    def set key, value
      @mutex.synchronize {
        logger.debug "Setting #{key} => #{value}"
        @context[key] = value
      }
    end

    # Retrieve the given key from the
    # context hash, or raise a
    # KeyError if it cannot be found.
    def get key
      logger.debug "Promising key [#{key}]"
      return Lazy::promise do
        @mutex.synchronize do
          logger.debug "Evaluated [#{key}] as [#{@context[key]}]"
          @context[key]
        end
      end
    end

    # Get a hash containing all keys
    # and values of the context
    def all
      @context
    end

    # Get the logger
    def logger
      @logger
    end

    private

    def create_accessor_method name, value
      var_name = "@#{name}".to_sym
      instance_variable_set var_name, value 
      logger.debug { "Creating #{value.class.name} accessor [#{name}] for value [#{value}]" }
      if value.is_a? Hash
        define_singleton_method name do |key|
          v = instance_variable_get var_name
          if v[key].nil?
            raise KeyError.new "Key #{key} does not exist in #{name}"
          end
          v[key]
        end

        define_singleton_method "all_#{name}" do
          instance_variable_get var_name
        end
      else
        define_singleton_method name do
          instance_variable_get var_name
        end
      end
    end

  end

end
