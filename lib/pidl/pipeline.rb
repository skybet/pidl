require 'lazy'
require 'thread'
require 'date'
require_relative 'base'
require_relative 'task'

module Pidl

  # A pipeline of tasks to be performed.
  #
  # This is the entry point to the Pidl pipeline system. It is responsible for
  # creating, running and cleaning up after any tasks that are part of the
  # pipeline.
  #
  # Tasks are created using the #task method from within the block. These are
  # named, usually with symbols, and stored in a hash. When it comes to
  # executing the tasks after the configuration phase, there are various
  # options:
  #
  # #explain::
  #   Calculate the running order of the tasks and return it, but do not run them.
  #
  # #dry_run::
  #   Display a summary of what would have happened had the tasks been run.
  #
  # #run::
  #   Run the tasks, either consecutively or incorporating concurrency depending on flags.
  #
  # During the running of the tasks, the #error_handler is used to clean up any
  # mess left by erroring code.
  #
  class Pipeline < PidlBase

    # A hash of tasks by name
    attr_reader :tasks

    # The error handler task, if configured by #on_error
    attr_reader :error_handler

    # Create a new pipeline and run its configuration block
    #
    # Adds two values to the context:
    #
    # * +:job_name+ The name parameter
    # * +:run_date+ DateTime.now
    #
    # Parameters:
    #
    # name::
    #   Any string used in logging
    #
    # context::
    #   A configured instance of Pidl::Context
    #
    # actions::
    #   A hash of actions and their associated classes
    #
    # block::
    #   The configuration block to execute
    #
    # The flags are used for two main tasks; configuring the way the tasks are
    # run, and adding commands for the tasks to use.
    #
    # [:single_thread]
    #   If true, do not use concurrency when running tasks
    #
    # [:actions]
    #   A hash of actions in the form { command => action class }
    #
    # Example:
    #
    #   actions = {
    #     file: MyModule::FileAction,
    #     dir: MyModule::DirAction
    #   }
    #   pipeline = Pipeline.new('test_pipeline', context, { actions: actions }, do ...
    #
    # The configured pipeline would have two new methods; +file+ and +dir+.
    # These methods would create instances of MyModule::FileAction and
    # MyModule::DirAction respectively and store them in the #tasks hash.
    #
    def initialize(name, context, flags = nil, &block)
      flags = flags || {}
      @single_thread = flags[:single_thread] or false
      @actions = flags[:actions] || {}
      @skip = flags[:skip] || []
      @tasks = {}

      begin
        @concurrency = if flags[:concurrency]
          Integer(flags[:concurrency])
        else
          0
        end
        @concurrency >= 0 || raise
      rescue => e
        raise ArgumentError.new "Invalid concurrency limit [#{flags[:concurrency]}]"
      end


      # Sort out the job name and date
      context.set :job_name, name.to_s
      context.set :run_date, ::DateTime.now

      super
    end

    # Create a new Pidl::Task with the given name and configuration block
    #
    # Once created, the task is added to #tasks. The tasks inherits the
    # pipeline's context.
    #
    # :call-seq:
    #   task :name, &block -> task
    #
    def task name, &block
      if ! @tasks[name].nil?
        raise ArgumentError.new "Type #{name} already exists"
      end
      logger.debug "Created task [#{name}]"
      add_task(create_task name, @context, @actions, &block)
    end

    # Create a special task for cleaning up after errors and adds it to #error_handler
    #
    # The task inherits the pipeline's context.
    #
    # :call-seq:
    #   on_error &block -> task
    #
    def on_error &block
      logger.debug "Created error handler"
      @error_handler = create_task(:error_handler, @context, @actions, &block)
    end

    # Add a pre-configured task to the #tasks hash
    #
    # Useful for unit testing or injecting specific programatically defined
    # tasks. Should not generally be used.
    #
    # :call-seq:
    #   add_task task -> task
    #
    def add_task task
      if ! @tasks[task.name].nil?
        raise ArgumentError.new "Type #{name} already exists"
      end
      logger.debug "Added pre-defined task [#{name}]"
      @tasks[task.name] = task
    end

    # Run the pipeline and all tasks
    #
    # Determine the task order using #explain and execute each group of tasks
    # in order, using either consecutive or concurrent threading models
    # depending on the +single_thread+ flag passed to the constructor.
    #
    # If the #skip? method is true for any reason, will not do anything.
    #
    # If any tasks' #skip? method returns true, that task will not be run.
    #
    # :call-seq:
    #   run
    #
    def run
      pipeline_start = Time.now
      plan = explain

      if skip?
        logger.info "Pipeline skipped"
        return
      end

      begin
        emit :pipeline_start, @name
        plan.each do |group|

          # Run single or multithreaded
          if @single_thread
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
      rescue Lazy::LazyException, StandardError => e
        if e.is_a? Lazy::LazyException
          e = e.reason
        end
        logger.error "Caught #{e.class.name}: attempting cleanup"
        attempt_cleanup
        raise e
      end

      pipeline_end = Time.now
      duration = ((pipeline_end - pipeline_start) * 1000).to_i
      logger.debug "#{to_s} completed in [#{duration}] ms"
      emit :pipeline_end, @name, duration
    end

    # Run a single named task
    #
    # If the named task exists, run it, otherwise raise an error.
    #
    # Does not take Pidl::Task#skip? or Pidl::Task#exit? into account.
    #
    # :call-seq:
    #   run_one
    #
    def run_one t
      emit :pipeline_start, @name
      pipeline_start = Time.now
      task = @tasks[t]
      if task
        task.run
      else
        raise RuntimeError.new "Cannot run invalid task [#{t}]"
      end
      pipeline_end = Time.now
      duration = ((pipeline_end - pipeline_start) * 1000).to_i
      logger.info "[TIMER] #{to_s} completed in [#{duration}] ms"
      emit :pipeline_end, @name, duration
    end

    # Generate an explain plan indicating the order of tasks
    #
    # Returns an array of arrays representing the groups of tasks. Each group in the outer array will be run one after the other. The tasks within each subarray will be run consecutively. For example, consider this explain plan:
    #
    #   [
    #     [ :setup ],
    #     [ :stage_one, :stage_two ],
    #     [ :unstage ]
    #   ]
    #
    # The :setup task will run first on its own. The :stage_one and :stage_two
    # tasks will then be run concurrently. Finally, the :unstage task will be
    # run on its own.
    #
    # In the case of single threaded execution, the groups with multiple tasks
    # will be run consecutively in no particular order.
    #
    # :call-seq:
    #   explain
    #
    def explain
      plan = build_plan
      check_plan plan
      logger.debug "Generated explain plan [#{plan}]"
      return plan
    end

    # Call dry_run on all tasks
    #
    # Order the tasks with #explain and call dry run, passing an indent in to
    # each to make an easily readable explanation of the actions that will
    # occur.
    #
    # :call-seq:
    #   dry_run indent=""
    #
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

    def emit_forwarder
      lambda { |*args| emit *args }
    end

    def bind_task_events task, handler
      task.on :task_start, handler
      task.on :task_end, handler
      task.on :action_start, handler
      task.on :action_end, handler
    end

    def unbind_task_events task, handler
      task.removeListener :task_start, handler
      task.removeListener :task_end, handler
      task.removeListener :action_start, handler
      task.removeListener :action_end, handler
    end

    def attempt_cleanup
      begin
        if @error_handler and not @error_handler.skip?
          @error_handler.run
        end
      rescue Lazy::LazyException, StandardError => e
        if e.is_a? Lazy::LazyException
          e = e.reason
        end
        logger.error "#{e.class.name} while running error handler: #{e.message}"
        logger.debug e.backtrace.join("\n")
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
      return build_plan( plan + split_for_concurrency(tasks) )
    end

    def check_plan plan
      f = plan.flatten
      if f.size != @tasks.size
        raise RuntimeError.new "Some tasks are unreachable [#{(@tasks.keys - f).join(", ")}]"
      end
    end

    private

    # Split an array of tasks based on concurrency limit.
    #
    # Accepts a list of tasks, returns an array of arrays
    # of tasks. If concurrency == 0 then return as a single
    # array, else group into @concurrency sized chunks
    #
    def split_for_concurrency tasks
      if @concurrency == 0
        [ tasks ]
      else
        tasks.each_slice(@concurrency).to_a
      end
    end

    # Create a new task instance and inject the custom actions into it
    #
    # Normally tasks do not have many actions available. We inject the custom
    # actions into each new task rather than create a new class derived from
    # Task for simplicity and expandability.
    #
    def create_task name, context, actions, &block
      Task.new name, context, logger: logger do
        actions.each { |name, type|
          add_custom_action name, type
        }
        instance_eval &block
      end
    end

    def skip_task? t
      @skip.include?(t) or @tasks[t].skip?
    end

    # Run a group of tasks consecutively
    #
    # Use a simple #each call. Order of tasks within a group is not guaranteed.
    #
    def run_group_series group
      group.each do |t|
        if not skip_task? t
          logger.info "Running task [#{t}]"

          # Listen
          forwarder = emit_forwarder
          bind_task_events @tasks[t], forwarder

          # Run
          @tasks[t].run

          # Stop listening
          unbind_task_events @tasks[t], forwarder
        else
          logger.debug "Skipping task [#{t}]"
        end
      end
    end

    # Run a group of tasks concurrently
    #
    # Use Lazy::future to get a list of thread handles and wait for them all.
    #
    # This way may not be particular configurable, and the slowest task in each
    # group will take as long as all the others in the same group. Instead of
    # "true" concurrency, this gives us a nice layered method of concurrency
    # that makes it very easy to reason about what is happening now and next.
    #
    def run_group_and_wait group
      mutex = Mutex.new
      events = []
      errors = []

      # Capture events emitted on other threads safely
      handler = lambda { |*args|
        mutex.synchronize {
          events.push args
        }
      }

      # Run the tasks
      futures = group.map do
        |t| Lazy::future do
          if not skip_task? t
            logger.info "Running task [#{t}]"

            # Listen
            bind_task_events @tasks[t], handler

            # Run
            begin
              @tasks[t].run
            rescue => e
              mutex.synchronize {
                errors << t
                logger.error "Error when executing task [:#{t}] - #{e.message}"
                logger.debug(e.backtrace.join("\n"))
              }
            ensure
              # Stop listening
              unbind_task_events @tasks[t], handler
            end

          else
            logger.debug "Skipping task [:#{t}]"
          end
        end
      end
      futures.each_with_index do |f, ix|
        logger.debug "Waiting for #{ix + 1} of #{futures.size}"
        Lazy::demand f
      end

      # Emit captured events
      events.each { |args|
        emit *args
      }

      # Raise the last error if there was one
      if errors.empty?
        logger.debug "All threads complete"
      elsif errors.size == 1
        raise "Error raised in task [#{errors[0]}] - Check the log for details."
      else
        raise "Errors raised in multiple tasks [#{errors.join(", ")}] - Check the log for details."
      end

    end
  end

end

