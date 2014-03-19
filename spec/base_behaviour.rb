require 'logger'
require 'context_behaviour'

shared_examples_for "PidlBase" do
  it_behaves_like "Context"

  def instance options={}, &block
    described_class.new :name_of_instance, @context, options, &block
  end

  def context_instance *args
    context = Context.send :new, *args
    described_class.new :name_of_instance, context do; end
  end

  before(:each) do
    @context = Context.new
  end

  describe "#name" do

    it "returns the specified name" do
      i = instance do; end
      i.name.should eq(:name_of_instance)
    end

  end

  describe "#logger" do

    it "returns a valid logger" do
      i = instance do; end
      l = i.logger
      l.is_a?(Logger).should eq(true)
    end

  end

end
