# Pidl

The PIpeline Definition Language provides a simple way to script pipelines of
work to do just about anything. Each pipeline is broken down into tasks, and
each task is broken down into actions. The actions can be built quickly and
easily and perform just about any task imaginable.

# Getting Started

Pidl pipelines are defined by a very simple, Ruby-esque DSL that should be
familiar with anyone who has used a Ruby DSL before. There are a handful of
simple constructs already created to get your first pipeline started.

``` ruby
require 'pidl'

context # Pidl::Context.new
pipeline # Pidl::Pipeline.new 'My Pipeline', context do

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

The Pidl::Context class makes use of lazy evaluation to provide a way to
pass values around during the parse phase of the pipeline definition, but
only realise them during the run phase. Consider the example of actions
using the context.

``` ruby
Pidl::Pipeline.new "My Pipeline", Pidl::Context.new() do

  task :my_task
    db "SELECT id, name FROM table WHERE column = value" do
      action :select_one
      field "name", :name
    end
  end

  task :output_task
    after :my_task
    db "UPDATE other_table SET name = ${name} WHERE column = value" do
      action :execute

      # The hypothetical #param method sets the query parameter
      param "name", get(:name)
  end

end
```

The call to `get(:name)` in `:output_task` returns a promise. When the
pipeline is parsed, there is no `:name` key in the context. That only
appears when the query in `:my_task` is run. When the action in
`:output_task` is run, however, and the query is parsed, there is a `:name`
key in the context so the correct value is retrieved.

For more information see http://moonbase.rydia.net/software/lazy.rb/

# Error Handling



