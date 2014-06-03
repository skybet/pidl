require 'pidl'
require 'base_behaviour'

include Pidl

describe Task do
  it_behaves_like "PidlBase"

  @context = nil

  def task &block
    return Task.new :name, @context, &block
  end

  def action(name=nil, &block)
    name ||= :actionname
    return Action.new name, @context, &block
  end

  before(:each) do
    @context = Context.new
  end

  describe "#ready?" do

    it "returns true if there are no dependencies" do
      t = task do; end
      t.ready?([]).should eq(true)
    end

    it "returns false if no dependencies have been seen" do
      t = task do
        after :dependency
      end
      t.ready?([]).should eq(false)
    end

    it "returns false if the dependency has not been seen" do
      t = task do
        after :dependency
      end
      t.ready?([ :notthisone ]).should eq(false)
    end

    it "returns false if none of the dependencies have been seen" do
      t = task do
        after :dependency, :another
      end
      t.ready?([ :notthisone ]).should eq(false)
    end

    it "returns false if some of the dependencies have been seen" do
      t = task do
        after :dependency, :another
      end
      t.ready?([ :dependency ]).should eq(false)
    end

    it "returns true if all of the dependencies have been seen" do
      t = task do
        after :dependency, :another
      end
      t.ready?([ :dependency, :another ]).should eq(true)
    end

  end

  describe "#first?" do

    it "returns true if there are no dependencies" do
      t = task do; end
      t.first?.should eq(true)
    end

    it "returns false if there are dependencies" do
      t = task do
        after :dependency
      end
      t.first?.should eq(false)
    end

  end

  describe "#run" do

    it "runs a single action" do
      t = task do; end
      a = t.add_action(action do; end)
      expect(a).to receive(:run)
      t.run
    end

    it "runs actions consecutively" do
      t = task do; end
      a = t.add_action(action do; end)
      b = t.add_action(action do; end)
      c = t.add_action(action do; end)
      expect(a).to receive(:run) do
        expect(b).to receive(:run) do
          expect(c).to receive(:run)
        end
      end
      t.run
    end

    it "skips actions that request it" do
      t = task do; end
      a = t.add_action(action do; end)
      b = t.add_action(action do; end)
      c = t.add_action(action do; end)

      allow(b).to receive(:skip?).and_return(true)
      expect(b).not_to receive(:run)
      expect(a).to receive(:run) do
        expect(c).to receive(:run)
      end

      t.run
    end

  end

  context "action error" do

    context "on_error :raise" do

      it "aborts all remaining actions and raises error" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :raise })
        b = t.add_action(action(:action_b) { on_error :raise })
        c = t.add_action(action(:action_c) { on_error :raise })

        expect(a).to receive(:run) do
          expect(b).to receive(:run).and_raise(RuntimeError.new "Test error") do
            expect(c).not_to receive(:run)
          end
        end

        expect do
          t.run
        end.to raise_error(RuntimeError)

        t.error?.should eq(true)
      end

    end

    context "on_error :exit" do
      it "aborts all remaining actions and sets exit? flag" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :exit })
        b = t.add_action(action(:action_b) { on_error :exit })
        c = t.add_action(action(:action_c) { on_error :exit })

        expect(a).to receive(:run) do
          expect(b).to receive(:run).and_raise(RuntimeError.new "Test error") do
            expect(c).not_to receive(:run)
          end
        end

        expect do
          t.run
        end.not_to raise_error

        t.exit?.should eq(true)
        t.error?.should eq(true)
        @context.get(:exit_code).should eq(0)
      end

      it "exits with the specified error code if set" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :exit, 101 })
        b = t.add_action(action(:action_b) { on_error :exit, 102 })
        c = t.add_action(action(:action_c) { on_error :exit, 103 })

        expect(a).to receive(:run) do
          expect(b).to receive(:run).and_raise(RuntimeError.new "Test error") do
            expect(c).not_to receive(:run)
          end
        end

        expect do
          t.run
        end.not_to raise_error

        t.exit?.should eq(true)
        t.error?.should eq(true)
        @context.get(:exit_code).should eq(102)
      end

      it "exits with error code 1 if error code is not an integer" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :exit, 'not an int' })

        expect(a).to receive(:run).and_raise(RuntimeError.new "Test error") do
        end

        expect do
          t.run
        end.not_to raise_error

        t.exit?.should eq(true)
        t.error?.should eq(true)
        @context.get(:exit_code).should eq(1)
      end

      it "exits with error code 0 if error code is 0" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :exit, 0 })

        expect(a).to receive(:run).and_raise(RuntimeError.new "Test error") do
        end

        expect do
          t.run
        end.not_to raise_error

        t.exit?.should eq(true)
        t.error?.should eq(true)
        @context.get(:exit_code).should eq(0)
      end
    end

    context "on_error :continue" do
      it "runs all remaining actions and does not set exit? flag" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :continue })
        b = t.add_action(action(:action_b) { on_error :continue })
        c = t.add_action(action(:action_c) { on_error :continue })

        expect(a).to receive(:run) do
          expect(b).to receive(:run).and_raise(RuntimeError.new "Test error") do
            expect(c).to receive(:run)
          end
        end

        expect do
          t.run
        end.not_to raise_error

        t.exit?.should eq(false)
        t.error?.should eq(false)
      end
    end

  end

end

