require 'lazy/threadsafe'
require_relative 'base'

module Pidl

  class Action < PidlBase

    # Create a setter method that does not require
    # an equals sign, as per attr_writer
    def self.setter(*method_names)
      method_names.each do |name|
        send :define_method, name do |value|
          instance_variable_set "@#{name}".to_sym, value 
        end
      end
    end

    # Create a setter method that does not require
    # an equals sign, as per attr_writer. It also
    # accepts a symbol, that is looked up lazily in
    # the context, or a block that is executed when
    # the action is run.
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

    # Create a setter method that does not require
    # an equals sign that groups all arguments
    # into an array
    def self.vargsetter(*method_names)
      method_names.each do |name|
        send :define_method, name do |*value|
          instance_variable_set "@#{name}".to_sym, value 
        end
      end
    end

    # Create a setter method that does not require
    # an equals sign that groups all arguments
    # into an array. Uses lazy evaluation.
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

    # Create a setter method that does not require
    # an equals sign that pushes the argument
    # into an internal array so it can be called
    # multiple times
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

    # Create a setter method that does not require
    # an equals sign that pushes the argument
    # into an internal array so it can be called
    # multiple times
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

    # Create a setter method that does not require
    # an equals sign that takes two arguments, a
    # key and a value, and stores them in an internal
    # hash so it can be called multiple times
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

    # Create a setter method that does not require
    # an equals sign that takes two arguments, a
    # key and a value, and stores them in an internal
    # hash so it can be called multiple times. Uses
    # lazy evaluation so symbols are read from context
    # and blocks are executed at runtime
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

    def initialize(name, context, flags = {}, &block)
      @on_error = :raise
      super
      validate
    end

    # Validate that the DSL entity and raise
    # a RuntimeError if not.
    #
    # Defaults to always return true. Override
    # in specific concrete classes if required.
    def validate
    end

    def run
    end

    def on_error v
      if not [:raise, :exit, :continue].include? v
        raise RuntimeError.new "Error response [#{v}] is invalid"
      end
      @on_error = v
    end

    def dry_run indent=""
      puts "#{indent}#{self}"
    end

    def to_s
      "#{self.basename}:#{@name}:#{@action}"
    end

    def raise_on_error?
      @on_error == :raise
    end

    def exit_on_error?
      @on_error == :exit
    end

    private

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


