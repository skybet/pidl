require_relative 'base'

module Pidl

  class Action < PidlBase

    def initialize(name, context, flags = {}, &block)
      super
    end

    def run
    end

    def dump
      puts "        #{self}"
    end

  end

end


