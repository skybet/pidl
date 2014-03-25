require_relative 'base'

module Pidl

  # A pipeline task that contains a number of actions to be performed.
  #
  # This is the basic unit of execution within a pipeline. Tasks can be ordered
  # by using the simple #after method to specify the name of a task or tasks
  # that theis task depends on. This is then used by Pidl::Pipeline#explain to
  # determine the optimal order for running tasks.
  #
  # Action methods are injected via the add_custom_action method by the
  # creating pipeline. Created actions are stored in an array and are run
  # consecutively in the order they were created.
  #
  class Task < PidlBase

    # Define an action method to create an action of a given type
    #
    # The action_sym parameter is a symbol representing the name of the method
    # used to instantiate this action. The type is a class derived from
    # Pidl::Action.
    #
    # New actions are added to the #actions array via #add_action
    #
    def add_custom_action(action_sym, type)
      define_singleton_method action_sym do |name = nil, &block|
        name ||= "#{@name}.#{action_sym}"
        a = type.new(name, @context, &block)
        add_action a
      end
    end

    # Specify a list of task names that this task depends on
    #
    # The list is stored as an array and used in the #first? and #ready?
    # methods.
    #
    def after *args
      @after = args
    end

    # Create a new Task instance
    #
    # See Pidl::Base::new
    #
    def initialize(name, context, flags = {}, &block)
      @actions = []
      @exit = false
      super
    end

    # Run all actions consecutively
    #
    # Run each action in the #actions array consecutively.
    #
    # If an action's #skip? method returns true, skip that action.
    #
    # If an action throws an error, query the Pidl::Action#raise_on_error? and
    # Pidl::Action#exit_on_error? to determine what to do. Reraise the error if
    # requested, or alternatively set the #exit? flag to true.
    #
    def run
      task_start = Time.now
      @actions.each do |action|
        begin
          if not action.skip?
            logger.info "Running action [#{action.to_s}]"
            action_start = Time.now
            action.run
            action_end = Time.now
            logger.info "[TIMER] #{action.to_s} completed in [#{((action_end - action_start) * 1000).to_i}] ms"
          else
            logger.debug "Skipping action [#{action.to_s}]"
          end
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

    # Get a list of all configured actions
    def actions
      @actions
    end

    # Add a preconfigured action
    #
    # Useful for injecting programmatically created actions or testing. Not to
    # be generally used.
    #
    def add_action(a)
      @actions << a
      a
    end

    # Return true if this task is one of the first to be run
    #
    # "First" is defined simply as "having no dependencies".
    def first?
      @after == nil || @after.empty?
    end

    # Return true if this task's dependencies are all met
    #
    # Given a list of already-run tasks, check that all the dependencies in
    # #after are listed.
    #
    def ready? seen
      if first?
        return true
      end
      @after.select {
        |x| !seen.include?(x)
      }.empty?
    end

    # Return true if an error has been raised by this or any other task
    #
    # Implemented as a check for :error in @context. True if not nil?
    def error?
      not get(:error).nil?
    end

    # Return true if, during the run, this task requested that the pipeline
    # exit.
    def exit?
      @exit
    end

    # Display a description of this task and all its actions, indented by 2 spaces
    def dry_run indent=""
      puts "#{indent}#{self}"
      @actions.each do |action|
        action.dry_run "#{indent}    "
      end
    end

  end

end

