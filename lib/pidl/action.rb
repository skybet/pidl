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

    def self.add_attribute name, default
      begin
        attributes = class_variable_get :@@attributes
      rescue
      end

      if attributes
        attributes[name] = default
      else
        class_variable_set :@@attributes, { name => default }
      end
    end

    # -------------------------------------------------------------------------
    # :section: Action Factories
    #
    # Action factories allow rapid creation of a variety of types of DSL
    # commands accepting various arguments and storing them in various formats.
    # The basic set of factories are:
    #
    # #setter::
    #   A simple value setter, accepts one argument and stores it
    #
    # #setterlazy::
    #   Like #setter, but uses Pidl::Promise and accepts lambdas and blocks
    #
    # #vargsetter::
    #   Like #setter, but accepts multiple arguments and stores them as an
    #   array
    #
    # #vargsetterlazy::
    #   Like #vargsetter, but uses Pidl::Promise and accepts
    #   lambdas
    #
    # #arraysetter::
    #   Like #setter, but stores values in an array and allows multiple calls
    #
    # #arraysetterlazy::
    #   Like #arraysetter, but uses Pidl::Promise and accepts lambdas and blocks
    #
    # #hashsetter::
    #   A simple key/value setter, accepts a key and a value and stores an
    #   internal hash. Allows multiple calls and overwrites duplicate keys.
    #
    # #hashsetterlazy::
    #   Like #hashsetter, but uses Pidl::Promise. Keys are not lazily
    #   evaluated. Accepts lambdas and blocks.
    # -------------------------------------------------------------------------

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
    # :call-seq:
    #   setter *method_names
    #
    # :category: Action Factories
    #
    def self.setter(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        self.add_attribute s, nil
        send :define_method, name do |value|
          instance_variable_set s, value
        end
      end
    end


    # Create a unary, non-repeatable DSL command with lazy evaluation
    #
    # See Pidl::Action::setter
    #
    # :call-seq:
    #   setterlazy *method_names
    #
    def self.setterlazy(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        self.add_attribute s, nil
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
          instance_variable_set s, get_lazy_wrapper(value, &block)
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
    # :call-seq:
    #   vargsetter *method_names
    #
    def self.vargsetter(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        self.add_attribute s, []
        send :define_method, name do |*value|
          instance_variable_set s, value
        end
      end
    end

    # Create an n-ary, non-repeatable DSL command with lazy evaluation
    #
    # See Pidl::Action::vargsetter
    #
    # :call-seq:
    #   vargsetterlazy *method_names
    #
    def self.vargsetterlazy(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        self.add_attribute s, []
        send :define_method, name do |*value, &block|
          value = value.map { |v| get_lazy_wrapper v }
          # For some reason block_given? returns false here
          # so use respond_to? :call instead
          if block.respond_to? :call
            value.push(get_lazy_wrapper(nil, &block))
          end
          instance_variable_set s, value
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
    # :call-seq:
    #   arraysetter *method_names
    #
    def self.arraysetter(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        instance_variable_set s, []
        self.add_attribute s, []
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
    # :call-seq:
    #   arraysetterlazy *method_names
    #
    def self.arraysetterlazy(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        instance_variable_set s, []
        self.add_attribute s, []
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
    # :call-seq:
    #   hashsetter *method_names
    #
    def self.hashsetter(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        self.add_attribute s, Hash.new
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
    # :call-seq:
    #   hashsetterlazy *method_names
    #
    def self.hashsetterlazy(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        self.add_attribute s, Hash.new
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

    # :section:

    # See Pidl::PidlBase::new
    def initialize(name, context, flags = {}, &block)
      name ||= self.class.name
      @action = nil
      @on_error = :raise
      @exit_code = nil
      begin
        attrs = self.class.class_variable_get(:@@attributes)
      rescue
        attrs = {}
      end
      attrs.each { |k,v|
        if not instance_variable_get(k)
          instance_variable_set k, (v ? v.dup : v)
        end
      }
      super
    end

    # Return a hash of all attribute values
    #
    # If true is passed in attempt to evaluate all lazy
    # attributes as part of this call
    #
    def attributes evaluate=false
      attributes = self.class.class_variable_get(:@@attributes) || Hash.new
      Hash[
        attributes.keys.map { |s|
          v = instance_variable_get s
          v = v.value if evaluate and v.is_a? Pidl::Promise
          k = s.to_s.sub(/^@/, '').to_sym
          [ k, v ]
        }
      ].merge action: @action
    end

    # Set the action to perform
    #
    # The parameter is usually a symbol for consistency.
    #
    # :call-seq:
    #   action :action
    #
    def action action
      @action = action
    end

    # See Pidl::PidlBase#run
    #
    # :call-seq:
    #   run
    def run
    end

    # See Pidl::PidlBase#dry_run
    #
    # :call-seq:
    #   dry_run indent=""
    def dry_run indent=""
      "#{indent}#{self}"
    end

    # Validate the basic parameters of the action.
    #
    # This is for validating the _configuration_ of the action, and as such
    # cannot be used to validate runtime values or effects. It normally
    # suffices to check that the requestion @action is a valid one.
    #
    # Called by Pidl::Action::new
    #
    # :call-seq:
    #   validate
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
    # If :exit is specified then a second parameter can be given to
    # set the exit code.
    #
    # :call-seq:
    #   on_error :value, exit_code=nil
    #
    def on_error v, exit_code=0
      if not [:raise, :exit, :continue].include? v
        raise RuntimeError.new "Error response [#{v}] is invalid"
      end
      @on_error = v
      if exit_code == 0
        @exit_code = 0
      elsif exit_code.respond_to? :to_i
        @exit_code = exit_code.to_i == 0 ? 1 : exit_code.to_i
      else
        @exit_code = 1
      end
      self
    end

    # If on_error is set to :exit and an exit code was provided,
    # return that exit code
    #
    def exit_code
      @exit_code
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
    # :call-seq:
    #   to_s -> str
    #
    def to_s
      "#{self.basename}:#{@name}:#{@action}"
    end

    # True if on_error called with :raise
    #
    # :call-seq:
    #   raise_on_error? -> bool
    def raise_on_error?
      @on_error == :raise
    end

    # True if on_error called with :exit
    #
    # :call-seq:
    #   exit_on_error? -> bool
    def exit_on_error?
      @on_error == :exit
    end

    # Convert an array with lazily evaluated values to a string
    #
    # Useful for generating dry_run messages. Replaces all Pidl::Promise
    # instances with their actual value if at all possible, or a ? if not.
    #
    # Output is of the form:
    #
    #     [ "val1", "val2" ]
    #
    def array_to_s params
      p = params.inject([]) { |a, v|
        begin
          if not v.instance_of? Pidl::Promise
            a.push("\"#{v}\"")
          else
            v = v.value
            v = v.nil? ? "?" : "\"#{v}\""
            a.push(v)
          end
        rescue Exception => e
          a.push("?")
        end
        a
      }
      p.size > 0 ? "[ #{p.join ", "} ]" : "[ ]"
    end

    # Convert a hash with lazily evaluated values to a string
    #
    # Useful for generating dry_run messages. Replaces all Pidl::Promise
    # instances with their actual value if at all possible, or a ? if not.
    #
    # Output is of the form:
    #
    #     { "key1" => "val1", "key2" => "val2" }
    #
    # If the type of a key is a Symbol, it is output as such
    # rather than being wrapped in quotes.
    #
    #     { :key1 => "val1", :key2 => "val2" }
    #
    def hash_to_s params
      p = params.keys.inject([]) { |a, k|
        key = k.is_a?(Symbol) ? ":#{k}" : "\"#{k}\""
        begin
          if not params[k].instance_of? Pidl::Promise
            a.push("#{key}=>\"#{params[k]}\"")
          else
            v = params[k].value
            v = v.nil? ? "?" : "\"#{v}\""
            a.push("#{key}=>#{v}")
          end
        rescue Exception => e
          a.push("#{key}=>?")
        end
        a
      }

      p.size > 0 ? "{ #{p.join ", "} }" : "{ }"
    end

  end

end


