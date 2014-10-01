require 'logger'
require 'context_behaviour'

shared_examples_for "PidlBase" do
  it_behaves_like "Context"
  it_behaves_like "EventEmitter"

  def instance options={}, &block
    described_class.new :name_of_instance, @context, options, &block
  end

  def context_instance *args
    context = Context.send :new, *args
    described_class.new :name_of_instance, context do; end
  end

  def emitter_instance
    context_instance
  end

  before(:each) do
    @context = Context.new
  end

  describe "#name" do

    it "returns the specified name" do
      i = instance do; end
      expect(i.name).to eq(:name_of_instance)
    end

  end

  describe "#logger" do

    it "returns a valid logger" do
      i = instance do; end
      l = i.logger
      expect(l.is_a?(Logger)).to eq(true)
    end

  end

  describe "#skip?" do

    it "returns false if no condition exists" do
      i = instance do; end
      expect(i.skip?).to eq(false)
    end

    it "returns false if a condition exists and is true" do
      i = instance do
        only_if { true }
      end
      expect(i.skip?).to eq(false)

    end

    it "returns true if a condition exists and is false" do
      i = instance do
        only_if { false }
      end
      expect(i.skip?).to eq(true)
    end

    it "returns true if a condition for a symbol exists and the symbol does not exist in context" do
      i = instance do
        only_if :my_key
      end
      expect(i.skip?).to eq(true)
    end

    it "returns false if a condition for a symbol exists and the symbol exists in context" do
      i = instance do
        only_if :my_key
      end
      i.set :my_key, 'value'
      expect(i.skip?).to eq(false)
    end

    it "returns true if a condition for a symbol exists and the symbol exists with a false value" do
      i = instance do
        only_if :my_key
      end
      i.set :my_key, false
      expect(i.skip?).to eq(true)
    end
  end

end
