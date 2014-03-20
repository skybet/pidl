require_relative 'base'

module Pidl

  class Task < PidlBase

    def add_custom_action(action_sym, type)
      define_singleton_method action_sym do |name = nil, &block|
        name ||= "#{@name}.#{action_sym}"
        a = type.new(name, @context, &block)
        add_action a
      end
    end

    def after *args
      @after = args
    end

    def initialize(name, context, flags = {}, &block)
      @actions = []
      @exit = false
      super
    end

    def run
      @actions.each do |action|
        begin
          logger.info "Running action [#{action.to_s}]"
          action.run
        rescue => e
          if action.raise_on_error?
            set(:error, e.message)
            raise
          elsif action.exit_on_error?
            set(:error, e.message)
            @exit = true
          end
          logger.info e.message
        end
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

    def exit?
      @exit
    end

    def dry_run indent=""
      puts "#{indent}#{self}"
      @actions.each do |action|
        action.dry_run "#{indent}    "
      end
    end

  end

end

