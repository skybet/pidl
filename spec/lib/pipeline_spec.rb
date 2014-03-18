require 'pidl'

include Pidl

describe Pipeline do

  @context = nil

  def pipeline options={}, &block
    return Pipeline.new :name, @context, options, &block
  end

  before(:each) do
    @context = Context.new({"job.prefix" => "maximus"}, {})
  end

  describe "@tasks" do

    it "has no tasks if none are added" do
      p = pipeline do
      end
      t = p.tasks
      t.size.should eq(0)
    end

    it "adds new tasks" do
      p = pipeline do
        task :mytask do
        end
      end
      t = p.tasks
      t.size.should eq(1)
      t[:mytask].name.should eq(:mytask)
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

  end

  describe "#explain" do

    it "return an empty array if there are no tasks" do
      p = pipeline do; end
      p.explain.should eq([])
    end

    it "returns a single task with no dependencies" do
      p = pipeline do
        task :onlytask do; end
      end
      p.explain.should eq([
                          [ :onlytask ]
      ])
    end

    it "groups tasks with no dependencies" do
      p = pipeline do

        task :firsttask do; end

        task :secondtask do; end

      end
      p.explain.should eq([
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
      p.explain.should eq([
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
      p.explain.should eq([
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
      p.explain.should eq([
                          [ :firsttask, :secondtask ],
                          [ :thirdtask ],
                          [ :fourthtask ]
      ])
    end

  end

  shared_examples_for "#run" do

    def task name, &block
      Task.new name, @context, &block
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

    ## Sample only - uncomment to watch
    # multi-threaded dispatch working
    #
    #it "does funky stuff with threads" do
    #    p = pipeline do; end

    #    t1 = task :firsttask do; end
    #    def t1.run
    #        sleep 16
    #        puts "t1"
    #    end
    #    p.add_task t1
    #    t2 = task :secondtask do; end
    #    def t2.run
    #        sleep 14
    #        puts "t2"
    #    end
    #    p.add_task t2
    #    t3 = task :thirdtask do; end
    #    def t3.run
    #        sleep 12
    #        puts "t3"
    #    end
    #    p.add_task t3
    #    t4 = task :fourthtask do; end
    #    def t4.run
    #        sleep 10
    #        puts "t4"
    #    end
    #    p.add_task t4
    #    p.run
    #end

  end

  context "run one" do

    def task name, &block
      Task.new name, @context, &block
    end

    it "runs a single task if run_one is set" do
      p = pipeline({ run_one: "secondtask" }) do; end

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
      p.run
    end

  end

  context "multi threaded" do
    it_behaves_like "#run"

    def get_pipeline
      pipeline do; end
    end
  end

  context "single threaded" do
    it_behaves_like "#run"

    def get_pipeline
      pipeline({ single_thread: true }) do; end
    end
  end

end

