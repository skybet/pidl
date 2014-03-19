require 'lazy'
require_relative 'base'
require_relative 'task'

module Pidl

  class Pipeline < PidlBase

    def initialize(name, context, flags = nil, &block)
      flags = flags || {}
      @run_one = flags[:run_one]
      @single_thread = flags[:single_thread] or false
      @tasks = {}

      # Sort out the job name
      context.store :job_name, name.to_s

      # Create out inner task type
      @tasktype = Class.new(Task) do
        actions = flags[:actions] || {}
        actions.each { |name, type|
          action name, type
        }
      end

      super
    end

    def task name, &block
      if ! @tasks[name].nil?
        raise ArgumentError.new "Type #{name} already exists"
      end
      logger.debug "Created task [#{name}]"
      @tasks[name] = @tasktype.new(name, @context, &block)
    end

    def tasks
      @tasks
    end

    def add_task task
      if ! @tasks[task.name].nil?
        raise ArgumentError.new "Type #{name} already exists"
      end
      logger.debug "Added pre-defined task [#{name}]"
      @tasks[task.name] = task
    end

    def run
      if @run_one
        t = @run_one.to_sym
        if @tasks[t]
          @tasks[t].run
        else
          throw RuntimeError.new "Cannot run invalid task [#{@run_one}]"
        end
      else
        plan = explain
        plan.each do |group|
          logger.debug "Running task group [#{group}]"
          if @single_thread
            run_group_series group
          else
            run_group_and_wait group
          end
        end
      end
    end

    def explain
      plan = build_plan
      check_plan plan
      logger.debug "Generated explain plan [#{plan}]"
      return plan
    end

    def dump
      puts self
      plan = explain
      plan.each do |group|
        group.each do |key|
          @tasks[key].dump
        end
      end
    end

    private

    def build_plan plan=[]
      p = plan.flatten
      tasks = @tasks.values.select {
        |x| not p.include?(x.name) and x.ready?(p)
      }.map {
        |x| x.name
      }
      if tasks.empty?
        return plan
      end
      return build_plan(plan + [ tasks ])
    end

    def check_plan plan
      f = plan.flatten
      if f.size != @tasks.size
        raise RuntimeError.new "Some tasks are unreachable [#{f.join(", ")}]"
      end
    end

    private

    def run_group_series group
      group.each do |t|
        logger.info "Running task [#{t}]"
        @tasks[t].run
      end
    end

    def run_group_and_wait group
      futures = group.map do
        |t| Lazy::future do
          logger.info "Running task [#{t}]"
          @tasks[t].run
        end
      end
      futures.each_with_index do |f, ix|
        logger.debug "Waiting for #{ix + 1} of #{futures.size}"
        Lazy::demand f
      end
      logger.info "All threads complete"
    end
  end

end

