module Pidl

  # Provide shared context to DSL entities
  #
  # The core functionality of the context object is to provide a key/value
  # store for use within a whole pipeline, shared amongst all entities. This
  # allows passing of values between actions, tasks and pipelines simple.
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

    # Check if the given key exists in the context
    #
    # :call-seq:
    #   is_set? key, value
    #
    def is_set? key
      @mutex.synchronize {
        logger.debug "Checking if #{key} exists"
        not @context[key].nil?
      }
    end

    # Store the given key/value pair in the context
    #
    # Overwrites previous values if present.
    #
    # :call-seq:
    #   set key, value
    #
    def set key, value
      @mutex.synchronize {
        logger.debug "Setting #{key} => #{value}"
        @context[key] = value
      }
    end

    # Retrieve the given key from the context and return the value
    #
    # :call-seq:
    #   get key -> mixed
    #
    def get key
      logger.debug "Promising key [#{key}]"
      @mutex.synchronize do
        logger.debug "Evaluated [#{key}] as [#{@context[key]}]"
        @context[key]
      end
    end

    # Get a hash containing all keys and values of the context
    #
    # :call-seq:
    #   all -> hash
    def all
      @context
    end

    # Get the logger
    #
    # :call-seq:
    #   logger -> Logger
    def logger
      @logger
    end

    private

    def create_accessor_method name, value
      var_name = "@#{name}".to_sym
      instance_variable_set var_name, value
      logger.debug { "Creating #{value.class.name} accessor [#{name}] for value [#{value unless value.to_s =~ /password/}]"}
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
