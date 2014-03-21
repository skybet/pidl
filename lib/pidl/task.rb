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
      task_start = Time.now
      @actions.each do |action|
        begin
          logger.info "Running action [#{action.to_s}]"
          action_start = Time.now
          action.run
          action_end = Time.now
          logger.info "[TIMER] #{action.to_s} completed in [#{((action_end - action_start) * 1000).to_i}] ms"
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
      task_end = Time.now
      logger.info "[TIMER] #{to_s} completed in [#{((task_end - task_start) * 1000).to_i}] ms"
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

