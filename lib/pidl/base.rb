require 'lazy'
require_relative 'fakelogger'
require_relative 'event'

module Pidl

  # Base class for all DSL entities
  #
  # Provides several key pieces of functionality:
  #
  # * Access to the global config
  # * Access to the global schema definitions
  # * Access to a shared context object
  #
  # The context object is used as a simple temporary key/value set to put
  # values in a shared place to enable simpler communication between tasks in a
  # pipeline. Methods on the context object are made available directly via the
  # method_missing handler.
  #
  # The constructor accepts a name and shared context as well as a block of
  # code to be run. This block is the actual DSL code and consists of method
  # calls against this entity, as well as any custom Ruby code (conditionals,
  # loops, etc) that may be required.
  #
  # The method calls used by the block should be only enough to configure the
  # object. The run method should then be called to take action based on that
  # configuration. This means that ordering is less vital and simplifies
  # handling dependencies between entities.
  #
  class PidlBase
    include EventEmitter

    # The given name of the DSL entity
    #
    # This is the name of a specific instance, not
    # the name of the type of thing it is.
    attr_reader :name

    # Initialize the DSL entity
    #
    # The provided block will be executed in instance context to allow in-line
    # configuration
    #
    # name::
    #   The name of this entity, usually a string or symbol
    #
    # context::
    #   A configured Pidl::Context instance
    #
    # flags::
    #   Additional configuration
    #
    # Valid flags include:
    #
    # [:logger]
    #   A standard Ruby logger to use (defaults to Pidl::FakeLogger)
    #

    def initialize(name, context, flags = {}, &block)
      @name = name
      @context = context
      @logger = flags[:logger] || FakeLogger.new
      instance_eval(&block)
    end

    # Convert to string
    #
    # :call-seq:
    #   to_s -> str
    def to_s
      "%s:%s" % [ self.basename, @name ]
    end

    # Return the configured logger
    #
    # :call-seq:
    #   logger -> Logger
    def logger
      @logger
    end

    # Return the context
    #
    # :call-seq:
    #   context -> Context
    def context
      @context
    end

    # Missing methods get passed on to the context
    def method_missing(name, *args, &block) # :nodoc:
      @context.send name, *args, &block
    end

    # Accept a block that evaluates to a boolean
    #
    # The block is evaluated only when #skip? is called, allowing this command
    # to be skipped instead of run.
    #
    # :call-seq:
    #   only_if &block
    #
    def only_if value=nil, &block
      if not value.nil? and block.respond_to? :call
        raise RuntimeError.new "Cannot accept value and block in condition"
      end

      # If no value provided, default to true
      if value.nil? and not block.respond_to? :call
        logger.warn "No value specified in condition"
        return
      end

      # Wrap a symbol in a lambda as it is just
      # an exists check
      if value.is_a? Symbol
        key = value
        value = lambda { not get(key).nil? and !!(get key)}
      end

      @only_if = get_lazy_wrapper value, &block
      nil
    end

    # Return true if the #only_if condition returns false
    #
    # :call-seq:
    #   skip? -> bool
    def skip?
      not (@only_if.nil? or !!(@only_if.value))
    end

    # Execute the DSL entity.
    #
    # Defaults to doing nothing at all. Override to provide functionality.
    #
    # :call-seq:
    #   run
    #
    def run
    end

    # Go through the motions of running but describe it to stdout instead
    #
    # Dump what would have happened to stdout. If indent is specified, prepend
    # it to the string before output.
    #
    # :call-seq:
    #   dry_run indent=""
    #
    def dry_run indent=""
    end

    protected

    # Return the name of this class without any module names prepended
    # :call-seq:
    #   basename -> str
    def basename
      self.class.name.split("::").last || ""
    end

    # Wrap a lazy value in a suitable promise
    #
    # [Symbol]
    #   Create a new promise that gets from @context
    #
    # [Proc]
    #   Create a new promise that evaluates on demand
    #
    # [Block]
    #   Create a new promise that evaluates on demand
    #
    # [Other]
    #   Create a promise that's already evaluated
    #
    def get_lazy_wrapper value, &block
      if value.is_a? Symbol
        Promise.new value, @context
      elsif block_given?
        Promise.new &block
      else
        Promise.new value
      end
    end

  end

end

