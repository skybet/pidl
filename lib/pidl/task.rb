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
    # The :name parameter is a symbol representing the name of the method
    # used to instantiate this action. The type is a class derived from
    # Pidl::Action.
    #
    # New actions are added to the #actions array via #add_action
    #
    # :call-seq:
    #   add_custom_action :name, type
    #
    def add_custom_action action_sym, type
      define_singleton_method action_sym do |name = nil, &block|
        name ||= "#{@name}.#{action_sym}"
        a = type.new(name, @context, { logger: @logger }, &block)
        add_action a
      end
    end

    # Specify a list of task names that this task depends on
    #
    # The list is stored as an array and used in the #first? and #ready?
    # methods.
    #
    # :call-seq:
    #   after *task_names
    #
    def after *task_names
      @after = task_names
    end

    # Create a new Task instance
    #
    # See Pidl::Base::new
    #
    def initialize(name, context, flags = {}, &block)
      if not name.is_a? Symbol
        name = name.to_s
      end
      @actions = []
      @exit = false
      @exit_code = nil
      super name.to_s.to_sym, context, flags, &block

      # Call logger after super so it can get set up properly
      if not name.is_a? Symbol
        logger.warn "Task name \"#{name}\" must be a symbol - converted to :#{name.to_sym}"
      end
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
    # :call-seq:
    #   run
    #
    def run
      task_start = Time.now
      emit :task_start, @name
      @actions.each do |action|
        begin
          if not action.skip?
            action_start = Time.now
            emit :action_start, action.to_s
            logger.info "Running action [#{action.to_s}]"
            action.run
            action_end = Time.now
            duration = ((action_end - action_start) * 1000).to_i
            logger.debug "[TIMER] #{action.to_s} completed in [#{duration}] ms"
            emit :action_end, action.to_s, duration
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
            set(:exit_code, action.exit_code)
          end
          logger.error e.message
        end
      end
      task_end = Time.now
      duration = ((task_end - task_start) * 1000).to_i
      logger.debug "#{to_s} completed in [#{duration}] ms"
      emit :task_end, @name, duration
    end

    # Get an array of all configured actions
    #
    # :call-seq:
    #   actions -> array
    def actions
      @actions
    end

    # Add a preconfigured action
    #
    # Useful for injecting programmatically created actions or testing. Not to
    # be generally used.
    #
    # :call-seq:
    #   add_action actions -> action
    #
    def add_action(a)
      a.validate
      @actions << a
      a
    end

    # Return true if this task is one of the first to be run
    #
    # "First" is defined simply as "having no dependencies".
    #
    # :call-seq:
    #   first? -> bool
    #
    def first?
      @after == nil || @after.empty?
    end

    # Return true if this task's dependencies are all met
    #
    # Given a list of already-run tasks, check that all the dependencies in
    # #after are listed.
    #
    # :call-seq:
    #   ready? -> bool
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
    #
    # :call-seq:
    #   error? -> bool
    #
    def error?
      not get(:error).nil?
    end

    # Return true if, during the run, this task requested that the pipeline
    # exit.
    #
    # :call-seq:
    #   exit? -> bool
    #
    def exit?
      @exit
    end

    # If an exit code has been set by an error handler, return it
    #
    # :call-set:
    #   exit_code -> integer
    #
    def exit_code
      @exit_code
    end

    # Display a description of this task and all its actions, indented by 2 spaces
    #
    # :call-seq:
    #   dry_run indent=""
    def dry_run indent=""
      puts "#{indent}#{self}"
      @actions.each do |action|
        puts action.dry_run("#{indent}    ")
      end
    end

  end

end

