require 'pidl'
require 'base_behaviour'
require 'date'

include Pidl

describe Pipeline do
  it_behaves_like "PidlBase"

  @context = nil

  def pipeline options={}, &block
    return Pipeline.new :name_of_job, @context, options, &block
  end

  def task name, &block
    Task.new name, @context, &block
  end

  def action name, &block
    Action.new name, @context, &block
  end

  before(:each) do
    @context = Context.new
  end

  describe "job name" do

    it "returns the job name via get" do
      i = pipeline do; end
      expect(i.get(:job_name)).to eq('name_of_job')
    end

    it "returns the job name via all" do
      i = pipeline do; end
      expect(i.all[:job_name]).to eq('name_of_job')
    end

  end

  describe "run date" do

    it "returns the datetime of the start of the test run" do
      test_start = DateTime.now.strftime('%s%L').to_i
      i = pipeline do; end
      test_end = DateTime.now.strftime('%s%L').to_i

      # run date should be between the test start and end
      # times. Easier than faffing with mocking the time.
      result = i.get(:run_date).strftime('%s%L').to_i
      expect(result).to be >= test_start
      expect(result).to be <= test_end
    end

  end

  describe "@tasks" do

    it "has no tasks if none are added" do
      p = pipeline do
      end
      t = p.tasks
      expect(t.size).to eq(0)
    end

    it "adds new tasks" do
      p = pipeline do
        task :mytask do
        end
      end
      t = p.tasks
      expect(t.size).to eq(1)
      expect(t[:mytask].name).to eq(:mytask)
    end

    it "raises an error if a duplicate task name is specified" do
      expect do
        p = pipeline do
          task :mytask do
          end

          task :mytask do
          end
        end
      end.to raise_error(ArgumentError)
    end

    it "converts string task identifiers to symbols" do
      p = pipeline do
        task "mytask" do
        end
      end
      t = p.tasks
      expect(t.size).to eq(1)
      expect(t[:mytask].name).to eq(:mytask)
    end

    it "handles types that cannot be converted directly to symbol by converting to string" do
      p = pipeline do
        task 6 do
        end
      end
      six_sym = 6.to_s.to_sym
      t = p.tasks
      expect(t.size).to eq(1)
      expect(t[six_sym].name).to eq(six_sym)
    end

  end

  describe "on_error" do

    it "adds an error handler task" do
      p = pipeline do
        on_error do
        end
      end
      expect(p.error_handler.name).to eq(:error_handler)
    end

    it "does not call error handler if no error" do
      p = pipeline do
        task :noerror do
        end

        on_error do
        end
      end
      expect(p.error_handler).not_to receive(:run)
      p.run
    end

    it "calls the error handler if an error is raised" do
      expect do
        p = pipeline do
          on_error do
          end
        end

        t = task :task do; end
        p.add_task(t)
        expect(t).to receive(:exit?).and_raise(RuntimeError.new "test")

        expect(p.error_handler).to receive(:run)
        p.run
      end.to raise_error(RuntimeError)
    end

    it "calls the error handler if a task exits with an error" do
      p = pipeline do
        on_error do
        end
      end

      t = task :task do; end
      p.add_task(t)
      expect(t).to receive(:exit?).and_return(true)
      expect(t).to receive(:error?).and_return(true)

      expect(p.error_handler).to receive(:run)
      p.run
    end

    it "does not call the error handler if a it should be skipped" do
      p = pipeline do
        on_error do
          only_if { false }
        end
      end

      t = task :task do; end
      p.add_task(t)
      expect(t).to receive(:exit?).and_return(true)
      expect(t).to receive(:error?).and_return(true)

      expect(p.error_handler).not_to receive(:run)
      p.run
    end

    it "does not call the error handler if a tasks exits with no error" do
      p = pipeline do
        on_error do
        end
      end

      t = task :task do; end
      p.add_task(t)
      allow(t).to receive(:exit?).and_return(true)
      allow(t).to receive(:error?).and_return(false)

      expect(p.error_handler).not_to receive(:run)
      p.run
    end

    it "calls the error handler if one task in a group exits with an error" do
      p = pipeline do
        on_error do
        end
      end

      t1 = task :task do; end
      p.add_task(t1)
      allow(t1).to receive(:exit?).and_return(false)
      allow(t1).to receive(:error?).and_return(false)

      t2 = task :task2 do; end
      p.add_task(t2)
      allow(t2).to receive(:exit?).and_return(true)
      allow(t2).to receive(:error?).and_return(true)

      expect(p.error_handler).to receive(:run)
      p.run
    end

    it "sets the exit code if a task exits with an error and code" do
      p = pipeline actions: { customaction: Action } do

      end

      a = action "test action" do
        on_error :exit, 101
      end
      t = task :task do; end
      t.add_action(a)
      p.add_task(t)
      expect(a).to receive(:run).and_raise(RuntimeError.new "Test")
      p.run
      expect(@context.get(:exit_code)).to eq(101)
    end

  end

  describe "custom actions" do

    it "returns a vanilla task if no custom actions are specified" do
      expect do
      p = pipeline do
        task :mytask do
          customaction :name
        end
      end
      end.to raise_error(NoMethodError)
    end

    it "returns a task blessed with the provided action" do
      p = pipeline actions: { customaction: Action } do
        task :mytask do
          customaction do; end
        end
      end
      expect(p.tasks.size).to eq(1)
      t = p.tasks[:mytask]
      a = t.actions[0]
      expect(a.name).to eq('mytask.customaction')
    end

    it "returns a task blessed with the provided action with a given name" do
      p = pipeline actions: { customaction: Action } do
        task :mytask do
          customaction "this is a custom name" do; end
        end
      end
      expect(p.tasks.size).to eq(1)
      t = p.tasks[:mytask]
      a = t.actions[0]
      expect(a.name).to eq('this is a custom name')
    end

  end

  describe "#explain" do

    it "return an empty array if there are no tasks" do
      p = pipeline do; end
      expect(p.explain).to eq([])
    end

    it "returns a single task with no dependencies" do
      p = pipeline do
        task :onlytask do; end
      end
      expect(p.explain).to eq([
                          [ :onlytask ]
      ])
    end

    it "groups tasks with no dependencies" do
      p = pipeline do

        task :firsttask do; end

        task :secondtask do; end

      end
      expect(p.explain).to eq([
                          [ :firsttask, :secondtask ]
      ])
    end

    it "raises an error if a task is unreachable" do
      p = pipeline do
        task :onlytask do
          after :missingtask
        end
      end
      expect { e = p.explain }.to raise_error(RuntimeError)
    end

    it "puts a task with one dependency after that dependency" do
      p = pipeline do
        task :secondtask do
          after :firsttask
        end

        task :firsttask do; end
      end
      expect(p.explain).to eq([
                          [ :firsttask ],
                          [ :secondtask ]
      ])
    end

    it "groups tasks whose dependencies are all met" do
      p = pipeline do
        task :firsttask do; end

        task :secondtask do
          after :firsttask
        end

        task :thirdtask do
          after :firsttask
        end
      end
      expect(p.explain).to eq([
                          [ :firsttask ],
                          [ :secondtask, :thirdtask ]
      ])
    end

    it "puts tasks with multiple dependencies after both dependencies" do
      p = pipeline do
        task :firsttask do; end

        task :secondtask do; end

        task :thirdtask do
          after :secondtask
        end

        task :fourthtask do
          after :firsttask, :thirdtask
        end
      end
      expect(p.explain).to eq([
                          [ :firsttask, :secondtask ],
                          [ :thirdtask ],
                          [ :fourthtask ]
      ])
    end

    it "respects max concurrency setting if set" do
      p = pipeline concurrency: 3 do

        task :firsttask do; end

        task :secondtask do; end

        task :thirdtask do; end

        task :fourthtask do; end
      end
      expect(p.explain).to eq([
                          [ :firsttask, :secondtask, :thirdtask ],
                          [ :fourthtask ]
      ])
    end

    it "raises an error if concurrency is not an integer" do
      expect do
        p = pipeline concurrency: "no" do; end
      end.to raise_error(ArgumentError)
    end

    it "raises an error if concurrency is less than 0" do
      expect do
        p = pipeline concurrency: -1 do; end
      end.to raise_error(ArgumentError)
    end

  end

  shared_examples_for "#run" do

    it "does nothing if the pipeline skips" do
      p = get_pipeline
      allow(p).to receive(:skip?).and_return(true)

      t = task :onlytask do; end
      p.add_task(t)

      expect(t).not_to receive(:run)
      p.run
    end

    it "runs a single task" do
      p = get_pipeline

      t = task :onlytask do; end
      p.add_task(t)

      expect(t).to receive(:run)
      p.run
    end

    it "runs multiple tasks" do
      p = get_pipeline

      t1 = task :firsttask do; end
      p.add_task(t1)

      t2 = task :secondtask do; end
      p.add_task(t2)

      expect(t1).to receive(:run)
      expect(t2).to receive(:run)
      p.run
    end

    it "raises an error if a task is unreachable" do
      p = get_pipeline

      t = task :onlytask do
        after :missingtask
      end
      p.add_task(t)

      expect {p.run}.to raise_error(RuntimeError)
    end

    it "runs tasks after their dependencies" do
      p = get_pipeline

      t1 = task :firsttask do
        after :secondtask
      end
      p.add_task(t1)

      t2 = task :secondtask do; end
      p.add_task(t2)

      expect(t2).to receive(:run) do
        expect(t1).to receive(:run)
      end
      p.run
    end

    it "groups tasks whose dependencies are all met" do
      p = get_pipeline

      t1 = task :firsttask do
        after :thirdtask
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :thirdtask
      end
      p.add_task(t2)

      t3 = task :thirdtask do; end
      p.add_task(t3)

      expect(t3).to receive(:run) do
        expect(t2).to receive(:run)
        expect(t1).to receive(:run)
      end
      p.run
    end

    it "puts tasks with multiple dependencies after both dependencies" do
      p = get_pipeline

      t1 = task :firsttask do
        after :secondtask, :fourthtask
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :thirdtask
      end
      p.add_task(t2)

      t3 = task :thirdtask do; end
      p.add_task(t3)

      t4 = task :fourthtask do; end
      p.add_task(t4)

      expect(t3).to receive(:run)
      expect(t4).to receive(:run) do
        expect(t2).to receive(:run) do
          expect(t1).to receive(:run)
        end
      end
      p.run
    end

    it "runs all tasks if non exit" do
      p = get_pipeline

      t1 = task :firsttask do
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :firsttask
      end
      p.add_task(t2)

      t3 = task :thirdtask do
        after :secondtask
      end
      p.add_task(t3)

      expect(t1).to receive(:run) do
        expect(t2).to receive(:run) do
          expect(t3).to receive(:run)
        end
      end
      p.run
    end

    it "does not run remaining tasks if one exits" do
      p = get_pipeline

      t1 = task :firsttask do
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :firsttask
      end
      p.add_task(t2)
      expect(t2).to receive(:exit?).and_return(true)

      t3 = task :thirdtask do
        after :secondtask
      end
      p.add_task(t3)

      expect(t1).to receive(:run) do
        expect(t2).to receive(:run) do
          expect(t3).not_to receive(:run)
        end
      end
      p.run
    end

    it "skip tasks that request it" do
      p = get_pipeline

      t1 = task :firsttask do
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :firsttask
      end
      allow(t2).to receive(:skip?).and_return(true)
      p.add_task(t2)

      t3 = task :thirdtask do
        after :firsttask
      end
      p.add_task(t3)

      expect(t2).not_to receive(:run)
      expect(t1).to receive(:run) do
        expect(t3).to receive(:run)
      end
      p.run
    end

    it "skip tasks on request" do
      p = get_pipeline skip: [:secondtask]

      t1 = task :firsttask do
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :firsttask
      end
      p.add_task(t2)

      t3 = task :thirdtask do
        after :secondtask
      end
      p.add_task(t3)

      expect(t2).not_to receive(:run)
      expect(t1).to receive(:run) do
        expect(t3).to receive(:run)
      end
      p.run
    end

    it "emits pipeline_start and pipeline_end events when the pipeline starts and completes" do
      probe_start = lambda { }
      probe_end = lambda { }

      expect(probe_start).to receive(:call) do |event, name|
        expect(name).to eq(:name_of_job)
        expect(probe_end).to receive(:call) do |event, name, duration|
          expect(name).to eq(:name_of_job)
          expect(duration.is_a?(Integer)).to eq(true)
        end
      end

      p = get_pipeline
      p.on :pipeline_start, &probe_start
      p.on :pipeline_end, &probe_end
      p.run
    end

    it "emits task_start and task_end events when each task starts and completes" do
      p = get_pipeline

      t1 = task :firsttask do
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :firsttask
      end
      p.add_task(t2)

      probe_start = lambda { }
      probe_end = lambda { }

      expect(probe_start).to receive(:call) do |event, name|
        expect(name).to eq(:firsttask)

        expect(probe_end).to receive(:call) do |event, name, duration|
          expect(name).to eq(:firsttask)
          expect(duration.is_a?(Integer)).to eq(true)

          expect(probe_start).to receive(:call) do |event, name|
            expect(name).to eq(:secondtask)

            expect(probe_end).to receive(:call) do |event, name, duration|
              expect(name).to eq(:secondtask)
              expect(duration.is_a?(Integer)).to eq(true)
            end
          end
        end
      end

      p.on :task_start, &probe_start
      p.on :task_end, &probe_end
      p.run
    end

    it "emits action_start and action_end events when each action starts and completes" do
      p = get_pipeline

      t1 = task :firsttask do
      end
      t1.add_action Action.new("action 1", @context) { action :test }
      t1.add_action Action.new("action 2", @context) { action :test }
      p.add_task(t1)

      probe_start = lambda { }
      probe_end = lambda { }

      expect(probe_start).to receive(:call) do |event, name|
        expect(name).to eq("Action:action 1:test")

        expect(probe_end).to receive(:call) do |event, name, duration|
          expect(name).to eq("Action:action 1:test")
          expect(duration.is_a?(Integer)).to eq(true)

          expect(probe_start).to receive(:call) do |event, name|
            expect(name).to eq("Action:action 2:test")

            expect(probe_end).to receive(:call) do |event, name, duration|
              expect(name).to eq("Action:action 2:test")
              expect(duration.is_a?(Integer)).to eq(true)
            end
          end
        end
      end

      p.on :action_start, &probe_start
      p.on :action_end, &probe_end
      p.run
    end

  end

  context "run one" do

    def task name, &block
      Task.new name, @context, &block
    end

    it "runs a single task if run_one is set" do
      p = pipeline() do; end

      t1 = task :firsttask do
        after :thirdtask
      end
      p.add_task(t1)

      t2 = task :secondtask do
        after :thirdtask
      end
      p.add_task(t2)

      t3 = task :thirdtask do; end
      p.add_task(t3)

      expect(t3).not_to receive(:run)
      expect(t2).to receive(:run)
      expect(t1).not_to receive(:run)
      p.run_one :secondtask
    end

    it "throws an error if the task is invalid" do

      p = pipeline() do; end

      t1 = task :firsttask do
      end
      p.add_task(t1)

      expect(t1).not_to receive(:run)

      expect do
        p.run_one :secondtask
      end.to raise_error(RuntimeError)
    end

  end

  context "multi threaded" do
    it_behaves_like "#run"

    def get_pipeline options={}
      pipeline options do; end
    end
  end

  context "single threaded" do
    it_behaves_like "#run"

    def get_pipeline options={}
      options[:single_thread] = true
      pipeline options do; end
    end
  end

end

