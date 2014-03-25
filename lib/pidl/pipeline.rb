require 'lazy'
require 'date'
require_relative 'base'
require_relative 'task'

module Pidl

  class Pipeline < PidlBase

    attr_reader :tasks, :error_handler

    def initialize(name, context, flags = nil, &block)
      flags = flags || {}
      @single_thread = flags[:single_thread] or false
      @actions = flags[:actions] || {}
      @tasks = {}

      # Sort out the job name and date
      context.set :job_name, name.to_s
      context.set :run_date, ::DateTime.now

      super
    end

    def task name, &block
      if ! @tasks[name].nil?
        raise ArgumentError.new "Type #{name} already exists"
      end
      logger.debug "Created task [#{name}]"
      @tasks[name] = create_task(name, @context, @actions, &block)
    end

    def on_error &block
      logger.debug "Created error handler"
      @error_handler = create_task(:error_handler, @context, @actions, &block)
    end

    def add_task task
      if ! @tasks[task.name].nil?
        raise ArgumentError.new "Type #{name} already exists"
      end
      logger.debug "Added pre-defined task [#{name}]"
      @tasks[task.name] = task
    end

    def run
      pipeline_start = Time.now
      plan = explain

      begin
        plan.each do |group|

          # Run single or multithreaded
          if @single_thread or group.size < 2
            logger.debug "Running task group [#{group}] consecutively"
            run_group_series group
          else
            logger.debug "Running task group [#{group}] concurrently"
            run_group_and_wait group
          end

          # See if we need to exit
          if group.reduce(false) { |r, t| r || @tasks[t].exit? }
            logger.debug "At least one task requested exit. Terminating now."

            # Check if an error was raised, and if so, clean up
            if group.reduce(false) { |r, t| r || @tasks[t].error? }
              attempt_cleanup
            end

            break
          end

        end
      rescue => e
        attempt_cleanup
        raise
      end

      pipeline_end = Time.now
      logger.info "[TIMER] #{to_s} completed in [#{((pipeline_end - pipeline_start) * 1000).to_i}] ms"
    end

    def run_one task
      pipeline_start = Time.now
      t = task
      if @tasks[t]
        @tasks[t].run
      else
        raise RuntimeError.new "Cannot run invalid task [#{task}]"
      end
      pipeline_end = Time.now
      logger.info "[TIMER] #{to_s} completed in [#{((pipeline_end - pipeline_start) * 1000).to_i}] ms"
    end

    def explain
      plan = build_plan
      check_plan plan
      logger.debug "Generated explain plan [#{plan}]"
      return plan
    end

    def dry_run indent=""
      puts indent + self.to_s
      plan = explain
      plan.each do |group|
        group.each do |key|
          @tasks[key].dry_run "#{indent}  "
        end
      end
    end

    private

    def attempt_cleanup
      begin
        if @error_handler
          @error_handler.run
        end
      rescue => e
        logger.error "Error while running error handler: #{e.message}"
      end
    end

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

    def create_task name, context, actions, &block
      Task.new name, context do
        actions.each { |name, type|
          add_custom_action name, type
        }
        instance_eval &block
      end
    end

    def run_group_series group
      group.each do |t|
        if not @tasks[t].skip?
          logger.info "Running task [#{t}]"
          @tasks[t].run
        else
          logger.debug "Skipping task [#{t}]"
        end
      end
    end

    def run_group_and_wait group
      futures = group.map do
        |t| Lazy::future do
          if not @tasks[t].skip?
            logger.info "Running task [#{t}]"
            @tasks[t].run
          else
            logger.debug "Skipping task [#{t}]"
          end
        end
      end
      futures.each_with_index do |f, ix|
        logger.debug "Waiting for #{ix + 1} of #{futures.size}"
        Lazy::demand f
      end
      logger.debug "All threads complete"
    end
  end

end

