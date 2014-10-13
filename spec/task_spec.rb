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

  describe "#new" do

    it "converts a non-symbol name to a symbol" do
      t = Task.new "my_task", @context do; end
      expect(t.name).to eq(:my_task)
    end

    it "converts to string before symbol if to_sym not supported" do
      t = Task.new 6, @context do; end
      expect(t.name).to eq("6".to_sym)
    end

  end

  describe "#ready?" do

    it "returns true if there are no dependencies" do
      t = task do; end
      expect(t.ready?([])).to eq(true)
    end

    it "returns false if no dependencies have been seen" do
      t = task do
        after :dependency
      end
      expect(t.ready?([])).to eq(false)
    end

    it "returns false if the dependency has not been seen" do
      t = task do
        after :dependency
      end
      expect(t.ready?([ :notthisone ])).to eq(false)
    end

    it "returns false if none of the dependencies have been seen" do
      t = task do
        after :dependency, :another
      end
      expect(t.ready?([ :notthisone ])).to eq(false)
    end

    it "returns false if some of the dependencies have been seen" do
      t = task do
        after :dependency, :another
      end
      expect(t.ready?([ :dependency ])).to eq(false)
    end

    it "returns true if all of the dependencies have been seen" do
      t = task do
        after :dependency, :another
      end
      expect(t.ready?([ :dependency, :another ])).to eq(true)
    end

  end

  describe "#first?" do

    it "returns true if there are no dependencies" do
      t = task do; end
      expect(t.first?).to eq(true)
    end

    it "returns false if there are dependencies" do
      t = task do
        after :dependency
      end
      expect(t.first?).to eq(false)
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

        expect(t.error?).to eq(true)
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

        expect(t.exit?).to eq(true)
        expect(t.error?).to eq(true)
        expect(@context.get(:exit_code)).to eq(0)
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

        expect(t.exit?).to eq(true)
        expect(t.error?).to eq(true)
        expect(@context.get(:exit_code)).to eq(102)
      end

      it "exits with error code 1 if error code is not an integer" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :exit, 'not an int' })

        expect(a).to receive(:run).and_raise(RuntimeError.new "Test error") do
        end

        expect do
          t.run
        end.not_to raise_error

        expect(t.exit?).to eq(true)
        expect(t.error?).to eq(true)
        expect(@context.get(:exit_code)).to eq(1)
      end

      it "exits with error code 0 if error code is 0" do
        t = task do; end
        a = t.add_action(action(:action_a) { on_error :exit, 0 })

        expect(a).to receive(:run).and_raise(RuntimeError.new "Test error") do
        end

        expect do
          t.run
        end.not_to raise_error

        expect(t.exit?).to eq(true)
        expect(t.error?).to eq(true)
        expect(@context.get(:exit_code)).to eq(0)
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

        expect(t.exit?).to eq(false)
        expect(t.error?).to eq(false)
      end
    end

  end

end

