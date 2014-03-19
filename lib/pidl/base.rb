require 'lazy'
require_relative 'fakelogger'

# The PIpeline Definition Language provides a simple way to script
# configuration of pipelines of work to be performed against the Maximus
# cluster. Each pipeline is broken down into tasks, and each task is broken
# down into actions.
#
# = Example
#
# The DSL consists of a series of classes that are created, configured and
# nested by blocks of pure Ruby code passed in to each one. The best way to
# illustrate this concept is by way of a small example:
#
#   pipeline "some_data.import" do
#
#       set :import_date, DateTime.now
#
#       task :clear_staging do
#
#           # Create the staging location, if it # doesn't exist hdfs do
#           action :mkdirs path schema("hdfs.db.staging") end
#
#           # Delete any old data hdfs do action :delete path
#           schema("hdfs.table.staging.some_data") end end
#
#       task :stage_data do after :clear_staging
#
#           # Grab the data from the DB sqoop do action :import file
#           "sql/import_some_data.ifx.sql" param "limit",
#           config("sqoop.limit.clause") done
#
#           # Find out the progress information hive do action :selectone
#           query "SELECT * FROM ${hive.table.staging.some_data}" field
#           "MAX_ID", :max_id field "MAX_DATE", :max_date end end
#
#       task :unstage_data do after :stage_data
#
#           # Merge the data in hive do action :execute file
#           "sql/unstage_some_data.sql" param "max_id", :max_id param
#           "max_date", :max_date end end
#
#       task :export_data do after :stage_data
#
#           # Format the data for export hive do action :execute file
#           "sql/export_some_data.sql" param "max_id", :max_id param
#           "import_data", get(:import_date).strftime("%F %T") end end
#
#       task :complete do after :unstage_data, :export_data
#
#           # Store the progress information hbase do action :put table
#           schema("hbase.table.some_data.id.set") param "data:LAST_ID",
#           :max_id end end
#
#   end
#
# Despite its simplicity, this is a complete example that could actually be
# used (assuming the config and schema values required were actually
# available to the Maximus class). All the major concepts of the DSL are
# included here.
#
# = Tasks and Actions
#
# The pipeline is broken town into tasks and actions. The tasks are easy to
# spot because they are created by calling #task and passing in the code that
# the task should execute.
#
# Actions are more subtle, but still simple; they are any blocks created
# inside a task. In this example, the #hdfs, #sqoop, #hive and #hbase calls
# produce actions inside tasks.
#
# == \Task Execution
#
# Tasks are executed according to dependency rules. These are specified by
# calling #after with a list of identifiers that should precede the current
# task. There are three ways to do this.
#
# First, have no dependencies. This makes the task a "first" task and it will
# be executed as soon as the pipeline is run.
#
#   task :some_task do end
#
# Second, have a single dependency. This will make the task run only when
# that dependency is met; i.e. when the named task has completed executing.
#
#   task :some_task do after :some_other_task end
#
# Third, have multiple dependencies. This is just like having a single
# dependency, but _all_ the named tasks must complete before the task will
# run.
#
#   task :some_task do after :some_other_task, :yet_another_task end
#
# Naming all dependencies means that the pipeline runner can run tasks
# concurrently such that a task is never started prematurely.
#
# == Action Execution
#
# Actions are much simpler than tasks; they are always executed consecutively
# based on the order of creation. If a hive action follows a sqoop action, it
# is safe to assume that the sqoop task will be finished before the hive
# action is run.
#
# There is no concurrency of actions within a task; they are purely linear.
# This simplifies task construction.
#
# = Config and Schema
#
# The #config and #schema functions are simple read-only accessors to
# underlying key/value sets. These are separated purely along semantic
# lines; they could well be loaded from the same configuration files. There
# are some key use differences that need to be taken into account when using
# them.
#
# == Config
#
# Calling #config with a string identifier will return the value associated
# with that key. If the value does not exist a KeyError is raised.
#
# The fact that the DSL block is executed in its entirety before any of the
# tasks are actions are run means that a KeyError when calling config will
# not cause the pipeline to terminate part-way through the run.
#
# The config method makes no guarantees about type. It is entirely likely
# that everything that is in config is stored as a string and may need
# casting, although that is generally left to the actions themselves.
#
# == Schema
#
# Calling #schema has identical behaviour to #config, in that it will return
# a value that is present, or raise a KeyError if not. The difference between
# the two is in the automatic use of schema within queries.
#
# Queries are automatically parsed, using values in the schema, by all the
# actions when they are configured. This is true whether the query comes from
# a string or a local file. The interpolation uses a bash style ${} format.
#
# Contrary to the schema variables, parameters are evaluated when the task is
# run. This means the queries go through a two-stage parsing process,
# although missing params are noted immediately.
#
# This interpolation is demonstrated in the :stage_data task in the example:
#
#    hive do action :selectone query "SELECT * FROM
#    ${hive.table.staging.some_data}" field "MAX_ID", :max_id field
#    "MAX_DATE", :max_date end
#
# The identifier ${hive.table.staging.some_data} will return the same value
# as a call to schema("hive.table.staging.some_data").
#
# = Context
#
# The context is automatically shared between the pipeline, tasks and actions
# and serves as a simple key/value set for maintaining state and passing
# values between tasks. It can be accessed at any time within the DSL block.
#
# The context is thread safe so that concurrent tasks will not trample on
# each other's calls to set.
#
# == Storing
#
# One way to set a value is to call set with a key and a value. The keys
# are generally Ruby symbols rather than strings, although they can be any
# scalar value. The reason is purely so that keys look different to values.
#
# From the example:
#
#   set :import_date, DateTime.now
#
# This demonstrates storing a value against a key, and also that normal Ruby
# code can be executed if required.
#
# == Retrieving
#
# Call the get function to get a stored value back. As with config and
# schema, retrieval will raise a KeyError if the requested key is not
# available.
#
# From the example:
#
#   hive do action :execute file "sql/export_some_data.sql" param "max_id",
#   get(:max_id) param "import_data",
#   get(:import_date).strftime("%F %T") end
#
# This demonstrates retrieving a value and, again, using Ruby code within the
# DSL block. In this case, the import date is formatted into a standard
# "YYYY-mm-dd HH:MM:SS" date/time string.
#
# == Automatic Storing
#
# Some actions can set values in the context automatically. This can be
# useful for retrieving database results or other deferred tasks. From the
# example:
#
#    hive do action :selectone query "SELECT * FROM
#    ${hive.table.staging.some_data}" field "MAX_ID", :max_id field
#    "MAX_DATE", :max_date end
#
# The calls to field provide the field name to be evaluated, and the key
# under which to set it in the context.
#
# == \Lazy Evaluation
#
# An important fact to be aware of is that return values from #get are
# evaluated lazily. In other words, the value is not actually getd from
# the context until it is actually used.
#
# This is necessary to allow the automatic storing facility to work properly.
# The query will not be run until the entire block has been executed and the
# #run method is called on the task. This means that the calls to #get
# later on cannot possibly succeed.
#
# By using lazy evaluation, the result of the call to #get will not
# actually be fetched until the action requires it. By that time, thanks to
# the dependency handling of the pipeline, the value should be set.
#
# This does not affect thread safety.
#
module Pidl

  # Base class for all DSL entities
  #
  # Provides several key pieces of functionality:
  #
  # * Access to the global config
  # * Access to the global schema definitions
  # * Access to a shared context object
  #
  # The context object is used as a simple
  # temporary key/value set to put values
  # in a shared place to enable simpler
  # communication between tasks in a pipeline.
  #
  # The constructor accepts a name and shared context
  # as well as a block of code to be run. This block
  # is the actual DSL code and consists of method
  # calls against this entity, as well as any custom
  # Ruby code (conditionals, loops, etc) that may
  # be required.
  #
  # The method calls used by the block should be
  # only enough to configure the object. The run
  # method should then be called to take action
  # based on that configuration. This means that
  # ordering is less vital and simplifies
  # handling dependencies between entities.
  class PidlBase

    # The given name of the DSL entity
    #
    # This is the name of a specific instance, not
    # the name of the type of thing it is.
    attr_reader :name

    # Initialize the DSL entity with a name
    # and a shared context, then execute the
    # provided block to allow in-line configuration.
    def initialize(name, context, flags = {}, &block)
      @name = name
      @context = context
      @logger = flags['logger'] || FakeLogger.new
      instance_eval(&block)
    end

    # Convert to string
    def to_s
      "%s:%s" % [ self.basename, @name ]
    end

    # Return the configured logger
    def logger
      @logger
    end

    # Store a value with the given key in
    # the internal context
    def set key, value
      @context.set key, value
    end

    # Retrieve the value of the given key
    # from the internal context
    def get key
      @context.get key
    end

    # Execute the DSL entity.
    #
    # Defaults to doing nothing at all.
    # Override to provide functionality.
    def run; end

    protected

    def basename
      self.class.name.split("::").last || ""
    end

  end

end

