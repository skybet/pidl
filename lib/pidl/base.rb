require 'lazy'
require_relative 'fakelogger'

module Pidl

  # Base class for all DSL entities
  #
  # Provides several key pieces of functionality:
  #
  # * Access to the global config
  # * Access to the global schema definitions
  # * Access to a shared context object
  #
  # The context object is used as a simple
  # temporary key/value set to put values
  # in a shared place to enable simpler
  # communication between tasks in a pipeline.
  #
  # The constructor accepts a name and shared context
  # as well as a block of code to be run. This block
  # is the actual DSL code and consists of method
  # calls against this entity, as well as any custom
  # Ruby code (conditionals, loops, etc) that may
  # be required.
  #
  # The method calls used by the block should be
  # only enough to configure the object. The run
  # method should then be called to take action
  # based on that configuration. This means that
  # ordering is less vital and simplifies
  # handling dependencies between entities.
  class PidlBase

    # The given name of the DSL entity
    #
    # This is the name of a specific instance, not
    # the name of the type of thing it is.
    attr_reader :name

    # Initialize the DSL entity with a name
    # and a shared context, then execute the
    # provided block to allow in-line configuration.
    def initialize(name, context, flags = {}, &block)
      @name = name
      @context = context
      @logger = flags[:logger] || FakeLogger.new
      instance_eval(&block)
    end

    # Convert to string
    def to_s
      "%s:%s" % [ self.basename, @name ]
    end

    # Return the configured logger
    def logger
      @logger
    end

    # Missing methods get passed on to the context
    def method_missing(name, *args, &block)
      @context.send name, *args, &block
    end

    # Allow if conditions on run
    def only_if &block
      if not block.respond_to? :call
        raise RuntimeError.new "If block should be callable"
      end
      @only_if = Lazy::promise &block
    end

    # Check if we should be skipped
    def skip?
      not (@only_if.nil? or @only_if)
    end

    # Execute the DSL entity.
    #
    # Defaults to doing nothing at all.
    # Override to provide functionality.
    def run; end

    protected

    def basename
      self.class.name.split("::").last || ""
    end

  end

end

