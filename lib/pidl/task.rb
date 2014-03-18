require_relative 'base'

module Pidl

  class Task < PidlBase

    def self.action(name, type)
      send :define_method, name do |&block|
        a = type.new("#{@name}.#{name}", @context, &block)
        add_action a
      end
    end

    vargsetter :after

    def initialize(name, context, flags = {}, &block)
      @cmds = []
      super
    end

    def run
      @cmds.each do |cmd|
        cmd.run
      end
    end

    def add_action(a)
      @cmds << a
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
      @cmds.each do |cmd|
        puts "        #{cmd.to_s}"
      end
    end

  end

end

