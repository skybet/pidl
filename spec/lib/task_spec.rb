require 'pidl'

include Pidl

describe Task do

  @context = nil

  def task &block
    return Task.new :name, @context, &block
  end

  def action &block
    return Action.new :actionname, @context, &block
  end

  before(:each) do
    @context = Context.new({}, {})
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

  end

end

