# Pidl

The PIpeline Definition Language provides a simple way to script pipelines
of work into discrete tasks that can be run in a managed way. The language
is extensible and allows for many different custom behaviours to be
injected at run-time so it can be configured precisely to the job at hand.

# Getting Started

Pidl pipelines are defined by a very simple, Ruby-esque DSL that should be
familiar with anyone who has used a Ruby DSL before. There are a handful of
simple constructs already created to get your first pipeline started.

``` ruby
require 'pidl'

context = Pidl::Context.new
pipeline = Pidl::Pipeline.new 'My Pipeline', context do

    task :first_task do
    # Put actions in here
    end

    task :second_task do
    after :first_task
    end

    task :third_task do
    after :first_task
    end

    task :fourth_task do
    after :first_task, :third_task
    end

    on_error do
    # Put error cleanup in here
    end

end
```

This pipeline will do absolutely nothing, but it will let us explore some
important aspects of the system.

## Running the Pipeline

Running the pipeline is achieved by calling Pidl::Pipeline#run.

    pipeline.run

The #run method will calculate the optimal grouping of tasks to ensure
dependencies are satisfied (more on those later) and execute all the tasks,
parallelising where possible.

## Explain Plan

In order to find out what the optimal grouping of tasks is that the run
method discovered, call instead the Pidl::Pipeline#explain method. This will
return an array of arrays containing groupings of tasks in the order they
should be run.

Executing Pidl::Pipeline#explain provides the following explain plan:

``` ruby
[
  [ first_task ],
  [ second_task, third_task ],
  [ fourth_task ]
]
```

Each group is a set of concurrent tasks. The first and third group only
contain one, but the second group has two, meaning that `:second_task` and
`:third_task` can be run concurrently because they do not depend on each other.

The Pidl::Pipeline#explain method also catches unreachable tasks and
recursive dependencies so you can be sure that the plan is sane.

A similar tool is Pidl::Pipeline#dry_run, which outputs a description of the
pipeline, each task and each action explaining exactly what the configured
parameters will do.

```
Pipeline:My Pipeline
  Task:first_task
  Task:second_task
```

## Loading from a script file

If you'd rather keep the boilerplate to a minimum, there is no reason not
to create a runner class that loads the pipeline definition from a file and
evaluates it in context of the runner.

``` ruby
require_relative 'lib/pidl'

class Runner

    def initialize filename
        script = File.read filename
        instance_eval script
    end

    def pipeline name, &block
        context = Pidl::Context.new
        @pipeline = Pidl::Pipeline.new name, context, &block
    end

    def run
        @pipeline.run
    end

    def dry_run
        @pipeline.dry_run
    end

    def explain
        @pipeline.explain
    end

end

runner = Runner.new ARGV[0]
runner.run
```

Just pass the filename of the script as the first argument. Sanity checking
and error handling is left to the reader. The script file would look like
this:

``` ruby
pipeline "My Pipeline" do
    task :first_task
        # Do something
    end
end
```

# Creating An Action

All actions are created as subclasses of the Pidl::Action class. A basic
task that does nothing but output its name may look like this:

``` ruby
class MeAction < Pidl::Action

  setter :surname

  def run
    case @action
    when :print
      puts "#{@name} #{@surname}"
    end
  end

  def dry_run indent=""
    case @action
    when :print
      puts "#{indent}#{basename}: Print name [#{@name}] with surname [#{surname}]"
    end
  end

end
```

Including this action in the DSL means adding it to the pipeline:

``` ruby
acts = {
  me: MeAction
}
pipeline = Pidl::Pipeline.new "My Pipeline", context, actions: acts do
  task :first_task do
    me "Joe" do
      action :print
      surname "Bloggs"
    end
  end
end
pipeline.dry_run
```

The output appears thus:

```
Pipeline:My Pipeline
  Task:first_task
    MeAction: Print name [Joe] with surname [Bloggs]
```

Running the pipeline results in the output `Joe Bloggs`, as you might expect.

Read Pidl::Action for more information about validation and other types of
command that can be added to an action.

# Context

Each Pidl class accepts a context argument that should be an instance of
Pidl::Context. This class provides a way to share state between tasks and
actions in the form of a key value store.

The context class is not visible from within defined pipelines. Rather, the
Pidl::PidlBase class from which Pidl::Pipeline, Pidl::Task and Pidl::Action
are defined passes method calls through to it, thus simplifying the Pidl
syntax.

## Basic Use

Context can be accessed from anywhere within the pipeline definition.

``` ruby
Pidl::Pipeline.new "My Pipeline", Pidl::Context.new() do
  set :thing, "value"

  task :first_task do
    puts get(:thing)

    puts 
  end
end.run
```

## Use in actions

Actions derived from Pidl::Action have access to the context from within
their own methods. This means that it is feasible build an action like
this:

``` ruby
Pidl::Pipeline.new "My Pipeline", Pidl::Context.new() do

  task :my_task

    # Hypothetical database access action
    db "SELECT id, name FROM table WHERE column = value" do
      action :select_one

      # The hypothetical #field method retrieves a column and puts it in
      # a named context variable
      field "name", :name
    end
  end

end
```

## Additional Context

It is possible to pass additional data to the context to make it available
to the pipeline. This is done by passing flags to the Pidl::Pipeline
constructor. These are made available via accessor methods that match the
flag names.

``` ruby
my_vars = {
  a_value: "value"
}
my_array = [
  'one',
  'two',
  'three'
]
context = Pidl::Context.new config: my_vars, params: my_array

Pidl::Pipeline.new "My Pipeline", context do
  task :first_task do
    # Hashes are exposed by a unary method that accepts the
    # key to be returned
    puts config(:a_value)

    # Hashes are also exposed as an all_* method to return
    # the entire hash
    puts all_config

    # Arrays, scalars and objects are returned as-is
    puts params[0]
  end
end.run
```

## A Note On Laziness

The Pidl::Action class makes use of lazy evaluation via Pidl::Promise to
provide a way to pass values around during the parse phase of the pipeline
definition, but only realise them during the run phase. Consider the
example of actions using the context.

``` ruby
Pidl::Pipeline.new "My Pipeline", Pidl::Context.new() do

  task :my_task do
    db "SELECT id, name FROM table WHERE column = value" do
      action :select_one
      field "name", :name
    end
  end

  task :output_task do
    after :my_task
    db "UPDATE other_table SET name = ${name} WHERE column = value" do
      action :execute

      # The hypothetical #param method sets the query parameter
      param "name", lambda { get(:name) }
  end

end
```

The call to `get(:name)` in `:output_task` is passed as a lambda, and it
wrapped in a promise. When the pipeline is parsed, there is no `:name` key
in the context. That only appears when the query in `:my_task` is run. When
the action in `:output_task` is run, however, and the query is parsed,
there is a `:name` key in the context so the correct value is retrieved.

This does mean that the following limitation exists:

``` ruby
Pidl::Pipeline.new "My Pipeline", Pidl::Context.new() do

  task :my_task do
    db "SELECT id, name FROM table WHERE column = value" do
      action :select_one
      field "name", :name
    end
  end

  task :output_task do
    after :my_task
    db "UPDATE other_table SET name = ${name} WHERE column = value" do
      action :execute

      # This breaks because using the value forces it to be evaluated,
      # and this key doesn't exist yet
      param "name", "Name: #{ get(:name) }"

      # The proper way to do it:
      param "name", lambda { "Name: #{ get(:name) }" }
    end
  end
end
```

The `param` method of the `db` action must be declared as a
`hashsetterlazy` command type. This means it accepts a block or lambda that is
evaluated as late as possible rather then during parsing.

For more information about lazy command types, see Pidl::Action.

An extra nicety is that, if using a lazy command type, the call to get can
be removed entirely, like this:

``` ruby

    db "UPDATE other_table SET name = ${name} WHERE column = value" do
      action :execute
      param "name", :name
    end
```

The lazy command types assume that if a symbol is passed in, it refers to a
context key and retrieves it when the action is run.

For more information see http://moonbase.rydia.net/software/lazy.rb/ and
Pidl::Action.

# Error Handling

Error handling in Pidl is largely based around cleaning up when an error
occurs rather than preventing or recovering from them. Of course, being
Ruby underneath, the normal error handlers can be used if you prefer, but
there are some built in constructs to assist in this regard.

## Error Handler in a Pipeline

At the Pidl::Pipeline level, tasks are run and may raise errors due to many
external factors. It is possible to add an error handler task that cleans
up anything that might get left behind in an error situatation. This is
done with the `on_error` command.

``` ruby
Pidl::Pipeline.new "My Pipeline", Pidl::Context.new() do

  task :setup do
    db "create_table.sql" do
      action :execute_file
    end

    db "fixture.sql" do
      action :import_from_file
      table "staging"
    end
  end

  task :export do
    db "procedure.sql" do
      action :execute_file
    end
  end

  on_error do
    db "DROP TABLE staging" do
      action :execute
    end
  end
end
```

In this contrived example, a file full of data is imported and then a
procedure is run on it. If something goes wrong, the staging table needs to
be removed. The task described by the `on_error` command does just that,
and is only run if something raises an error and forces the pipeline to
terminate.

## Error Handler in an Action

Consider our previous contrived example. This time, instead of deleting the
staging table, it should be left for future debugging. However, if the
import fails the pipeline should exit gracefully because there is nothing
to do.

``` ruby
Pidl::Pipeline.new "My Pipeline", Pidl::Context.new() do

  task :setup do
    db "create_table.sql" do
      action :execute_file
    end

    db "fixture.sql" do
      action :import_from_file
      table "staging"
      on_error :exit
    end
  end

  task :export do
    db "procedure.sql" do
      action :execute_file
    end
  end
end
```

The `on_error` command within an action takes on a different meaning. It
allows a flag to be set to tell it how to behave. The possible options are:

`:raise`
: Raise an error (this is the default)

`:exit`
: Exit the pipeline cleanly

`:continue`
: Ignore the error and continue


