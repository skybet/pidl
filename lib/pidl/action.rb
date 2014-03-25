require 'lazy/threadsafe'
require_relative 'base'

module Pidl

  # Base class of all configurable actions.
  #
  # Provides utility methods to create DSL commands as methods/attributes and
  # an overrideable run and validate method.
  #
  # To use this class, create a new class that inherits from it, create one or
  # more commands using the helper functions, and override the #run method.
  # Override #validate to add basic validation to the structure of the action.
  #
  # DSL command utility methods come in two varieties; lazy and non-lazy.
  # Non-lazy commands accept the given arguments as-is and store them verbatim.
  # Lazy commands accept a wider variety of arguments and evaluate them only
  # when demanded. This can be used to set up actions at parse time that will
  # not execute until runtime.
  #
  # Lazy commands accept arguments of the following sorts:
  #
  # normal value:: store the value as-is
  #
  # symbol:: lazily evaluate Context#get for the given key
  #
  # lambda:: lazily evaluate the lambda when demanded
  #
  # block:: lazily evaluate the given block when demanded
  #
  class Action < PidlBase

    # Create a unary, non-repeatable DSL command
    #
    # Accepts a single argument and stores it in an instance variable of the
    # same name. Will overwrite the previous value if called again.
    #
    # Example:
    #
    #   setter :mycommand
    #
    # Results in:
    #
    #   def mycommand value
    #     @mycommand = value
    #   end
    #
    def self.setter(*method_names)
      method_names.each do |name|
        send :define_method, name do |value|
          instance_variable_set "@#{name}".to_sym, value
        end
      end
    end


    # Create a unary, non-repeatable DSL command with lazy evaluation
    #
    # See Pidl::Action::setter
    #
    def self.setterlazy(*method_names)
      method_names.each do |name|
        send :define_method, name do |value=nil, &block|
          # Raise an error if both specified
          if not value.nil? and block.respond_to? :call
            raise RuntimeError.new "Cannot accept value and block in lazy hashsetter"
          end

          # If no value provided, default to true
          if value.nil? and not block.respond_to? :call
            logger.warn "No value specified in call to \##{name}"
            return
          end
          instance_variable_set "@#{name}".to_sym, get_lazy_wrapper(value, &block)
        end
      end
    end

    # Create an n-ary, non-repeatable DSL command
    #
    # Accepts multiple arguments and stores them as an array in an instance
    # variable of the same name. Will overwrite the previous value if called
    # again.
    #
    # Example:
    #
    #   vargsetter :mycommand
    #
    # Results in:
    #
    #   def mycommand *values
    #     @mycommand = values
    #   end
    #
    def self.vargsetter(*method_names)
      method_names.each do |name|
        send :define_method, name do |*value|
          instance_variable_set "@#{name}".to_sym, value
        end
      end
    end

    # Create an n-ary, non-repeatable DSL command with lazy evaluation
    #
    # See Pidl::Action::vargsetter
    #
    def self.vargsetterlazy(*method_names)
      method_names.each do |name|
        send :define_method, name do |*value, &block|
          value = value.map { |v| get_lazy_wrapper v }
          # For some reason block_given? returns false here
          # so use respond_to? :call instead
          if block.respond_to? :call
            value.push(get_lazy_wrapper(nil, &block))
          end
          instance_variable_set "@#{name}".to_sym, value
        end
      end
    end

    # Create a unary, repeatable DSL command
    #
    # Accepts a single argument and stores it in an array. Will add to the array if called again.
    #
    # Example:
    #
    #   arraysetter :mycommand
    #
    # Results in:
    #
    #   def mycommand value
    #     if @mycommand.nil?
    #       @mycommand = [ value ]
    #     else
    #       @mycommand.push value
    #     end
    #   end
    #
    def self.arraysetter(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        instance_variable_set s, []
        send :define_method, name do |value|
          v = instance_variable_get s
          if v.nil?
            instance_variable_set s, [ value ]
          else
            v.push(value)
          end
        end
      end
    end

    # Create a unary, repeatable DSL command with lazy evaluation
    #
    # See Pidl::Action::arraysetter
    #
    def self.arraysetterlazy(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        instance_variable_set s, []
        send :define_method, name do |value=nil, &block|
          # Raise an error if both specified
          if not value.nil? and block.respond_to? :call
            raise RuntimeError.new "Cannot accept value and block in lazy hashsetter"
          end

          # If no value provided, default to true
          if value.nil? and not block.respond_to? :call
            logger.warn "No value specified in call to \##{name}"
            return
          end

          v = instance_variable_get s
          value = get_lazy_wrapper value, &block
          if v.nil?
            instance_variable_set s, [ value ]
          else
            v.push(value)
          end
        end
      end
    end

    # Create a binary, repeatable DSL command
    #
    # Accepts a pair of arguments; a key and a value. Stores the value against
    # the given key in a hash of the same name. Will add to the hash if called
    # again, and overwrite if the same key is specified twice.
    #
    # Example:
    #
    #   hashsetter :mycommand
    #
    # Results in:
    #
    #   def mycommand key, value
    #     if @mycommand.nil?
    #       @mycommand = { key => value }
    #     else
    #       @mycommand[key] = value
    #     end
    #   end
    #
    def self.hashsetter(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        send :define_method, name do |key, value=true|
        v = instance_variable_get s
        if v.nil?
          instance_variable_set s, { key => value }
        else
          v[key] = value
        end
        end
      end
    end

    # Create a binary, repeatable DSL command
    #
    # See Pidl::Action::hashsetter
    #
    def self.hashsetterlazy(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        send :define_method, name do |key, value=nil, &block|

        # Raise an error if both specified
        if not value.nil? and block.respond_to? :call
          raise RuntimeError.new "Cannot accept value and block in lazy hashsetter"
        end

        # If no value provided, default to true
        if value.nil? and not block.respond_to? :call
          logger.warn "No value specified in call to \##{name}"
          return
        end

        v = instance_variable_get s
        value = get_lazy_wrapper value, &block
        if v.nil?
          instance_variable_set s, { key => value }
        else
          v[key] = value
        end
        end
      end
    end

    # The action attribute and command to set it
    setter :action

    # See Pidl::PidlBase::new
    def initialize(name, context, flags = {}, &block)
      @on_error = :raise
      super
      validate
    end

    # See Pidl::PidlBase#run
    def run
      puts "#{indent}#{self}"
    end

    # See Pidl::PidlBase#dry_run
    def dry_run indent=""
      puts "#{indent}#{self}"
    end

    # Validate the basic parameters of the action.
    #
    # This is for validating the _configuration_ of the action, and as such
    # cannot be used to validate runtime values or effects. It normally
    # suffices to check that the requestion @action is a valid one.
    #
    # Called by Pidl::Action::new
    #
    def validate
    end

    # Set a flag to indicate what to do in case of error.
    #
    # Specify the requested course of action if an error is raised as part of
    # the #run method of this action. Note that this is a request only; the
    # caller can opt to ignore the request.
    #
    # Valid values are
    #
    # [:raise] Raise an error (default) 
    #
    # [:exit] Cleanly stop executing the current pipeline
    #
    # [:continue] Carry on as if the error did not happen
    #
    def on_error v
      if not [:raise, :exit, :continue].include? v
        raise RuntimeError.new "Error response [#{v}] is invalid"
      end
      @on_error = v
    end

    # Convert this action to a string
    #
    # Default format is:
    #
    #   {class name}:{action name}:{action to perform}
    #
    # For example:
    #
    #   File:/tmp/myfile:delete
    #
    def to_s
      "#{self.basename}:#{@name}:#{@action}"
    end

    # True if on_error called with :raise
    def raise_on_error?
      @on_error == :raise
    end

    # True if on_error called with :exit
    def exit_on_error?
      @on_error == :exit
    end

    private

    # Wrap a lazy value in a suitable promise
    #
    # [Symbol]
    #   Get a promise from @context
    #
    # [Proc]
    #   Create a new promise that evaluates on demand
    #
    # [Block]
    #   Create a new promise that evaluates on demand
    #
    # [Other]
    #   Do not create a promise; already evaluated
    #
    def get_lazy_wrapper value, &block
      if value.is_a? Symbol
        get(value)
      elsif value.respond_to? :call
        Lazy::promise do
          value.call
        end
      elsif block_given?
        Lazy::promise &block
      else
        value
      end
    end

    # Convert a hash with lazily evaluated values to a string
    #
    def params_to_s params
      p = params.keys.inject([]) { |a, k|
        begin
          # Check type forces evaluation
          if not params[k].instance_of? Lazy::Promise
            a.push("\"#{k}\"=>\"#{params[k]}\"")
          else
            a.push("\"#{k}\"=>\"#{Lazy::demand params[k]}\"")
          end
        rescue Lazy::LazyException
          a.push("\"#{k}\"=>?")
        rescue Exception => e
          raise e
        end
        a
      }

      p.size > 0 ? "{ #{p.join ", "} }" : "{ }"
    end

  end

end


