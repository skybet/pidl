require 'thread'
require 'lazy'

module Pidl

  # Provide shared context to DSL entities
  #
  # The core functionality of the context object is to provide a key/value
  # store for use within a whole pipeline, shared amongst all entities. This
  # allows passing of values between actions, tasks and pipelines simple.
  #
  # All requests to retrieve values are lazily evaluated. This means that it is
  # possible to retrieve a value and pass it around, but the value will not
  # actually be retrieved until it is specifically requested by attempting to
  # evaluate or interrogate the value. This makes it possible to retrieve
  # values that have not yet been inserted. For example:
  #
  #   task :example_task do
  #     first_action do
  #       do_deferred_thing_and_store_as :my_key
  #     end
  #     second_action do
  #       do_deferred_thing get(:my_key)
  #     end
  #   end
  #
  # In this scenario, +:my_key+ is not stored until +first_action+ is run.
  # However, +second_action+ retrieves +:my_key+ and passes it to
  # +do_deferred_thing+ during the initial parse phase. This only works because
  # the value passed to +do_deferred_thing+ is not evaluated until the
  # +do_deferred_thing+ action is run and it requests the value of the object.
  # Until then it is just blindly stored.
  #
  class Context

    # Create a new, empty context
    #
    # Flags can contain any number of keys and these are exposed via the public
    # interface of the new object. The nature of the interface depends on the
    # type of the object passed in.
    #
    # Example:
    #
    #   cfg = { 'a config key' => 'a config value' }
    #   context = Context.new config: cfg
    #
    # This will make the +config+ method available as a ready-only way to
    # access the hash passed into the flags.
    #
    #   v = context.config('a config key')
    #   # v == 'a config value'
    #
    # A hash is exposed as a unary method that takes a key and returns a value
    # from the hash.
    #
    # Arrays and scalar variables are exposed as a nullary method that returns
    # the whole value.
    #
    # The only exception is the special flag +:logger+. This should contain the
    # configured logger to use within this context. If not specified, it
    # defaults to Pidl::FakeLogger.
    #
    def initialize(flags = {})
      @context = {}
      @mutex = Mutex.new
      @logger = flags[:logger] || FakeLogger.new
      flags.delete :logger

      # Create custom accessors for the flags
      flags.each { |name, value|
        create_accessor_method name, value
      }
    end

    # Store the given key/value pair in the context
    #
    # Overwrites previous values if present.
    #
    def set key, value
      @mutex.synchronize {
        logger.debug "Setting #{key} => #{value}"
        @context[key] = value
      }
    end

    # Retrieve the given key from the context and return the value
    #
    # The value is lazily evaluated and synchronized.
    #
    def get key
      logger.debug "Promising key [#{key}]"
      return Lazy::promise do
        @mutex.synchronize do
          logger.debug "Evaluated [#{key}] as [#{@context[key]}]"
          @context[key]
        end
      end
    end

    # Get a hash containing all keys and values of the context
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
