require 'pidl'
require 'base_behaviour'

include Pidl

describe Action do
  it_behaves_like "PidlBase"

  @context = nil

  def action &block
    return Action.new :actionname, @context, &block
  end

  before(:each) do
    @context = Context.new
  end

  describe "#on_error" do

    it "raises an error on invalid value" do
      expect do
        a = action do
          on_error :explode
        end
      end.to raise_error
    end

    describe "#raise_on_error?" do

      it "returns true if on_error is not set" do
        a = action do
        end
        a.raise_on_error?.should eq(true)
      end

      it "returns true if on_error is :raise" do
        a = action do
          on_error :raise
        end
        a.raise_on_error?.should eq(true)
      end

      it "returns false if on_error is :exit" do
        a = action do
          on_error :exit
        end
        a.raise_on_error?.should eq(false)
      end

      it "returns false if on_error is :continue" do
        a = action do
          on_error :continue
        end
        a.raise_on_error?.should eq(false)
      end

    end

    describe "#exit_on_error?" do

      it "returns false if on_error is not set" do
        a = action do
        end
        a.exit_on_error?.should eq(false)
      end

      it "returns true if on_error is :exit" do
        a = action do
          on_error :exit
        end
        a.exit_on_error?.should eq(true)
      end

      it "returns false if on_error is :raise" do
        a = action do
          on_error :raise
        end
        a.exit_on_error?.should eq(false)
      end

      it "returns false if on_error is :continue" do
        a = action do
          on_error :continue
        end
        a.exit_on_error?.should eq(false)
      end

    end

  end
end
