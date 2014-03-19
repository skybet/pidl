require_relative 'base'

module Pidl

  class Action < PidlBase

    # Create a setter method that does not require
    # an equals sign, as per attr_writer
    def self.setter(*method_names)
      method_names.each do |name|
        send :define_method, name do |data|
          instance_variable_set "@#{name}".to_sym, data 
        end
      end
    end

    # Create a setter method that does not require
    # an equals sign that groups all arguments
    # into an array
    def self.vargsetter(*method_names)
      method_names.each do |name|
        send :define_method, name do |*data|
          instance_variable_set "@#{name}".to_sym, data 
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
        send :define_method, name do |data|
          v = instance_variable_get s
          if v.nil?
            instance_variable_set s, [ data ]
          else
            v.push(data)
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
    # hash so it can be called multiple times. If
    # the value is a symbol, retrieve that symbol
    # from the context
    def self.hashsettercontext(*method_names)
      method_names.each do |name|
        s = "@#{name}".to_sym
        send :define_method, name do |key, value=true|
        v = instance_variable_get s
        if value.is_a? Symbol
          value = retrieve(value)
        end
        if v.nil?
          instance_variable_set s, { key => value }
        else
          v[key] = value
        end
        end
      end
    end

    def initialize(name, context, flags = {}, &block)
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

    def dump
      puts "        #{self}"
    end

    private

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


