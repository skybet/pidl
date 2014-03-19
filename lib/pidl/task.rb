require_relative 'base'

module Pidl

  class Task < PidlBase

    def self.action(name, type)
      send :define_method, name do |&block|
        a = type.new("#{@name}.#{name}", @context, &block)
        add_action a
      end
    end

    def after *args
      @after = args
    end

    def initialize(name, context, flags = {}, &block)
      @actions = []
      super
    end

    def run
      @actions.each do |action|
        action.run
      end
    end

    def actions
      @actions
    end

    def add_action(a)
      @actions << a
      a
    end

    def first?
      @after == nil || @after.empty?
    end

    def ready? seen
      if first?
        return true
      end
      @after.select {
        |x| !seen.include?(x)
      }.empty?
    end

    def dump
      puts "    #{self}"
      @actions.each do |action|
        puts "        #{action.to_s}"
      end
    end

  end

end

