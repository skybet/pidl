require 'logger'

shared_examples_for "PidlBase" do

  def instance options={}, &block
    return described_class.new :name, @context, options, &block
  end

  before(:each) do
    @context = Context.new
  end

  describe "#name" do

    it "returns the specified name" do
      i = instance do; end
      i.name.should eq(:name)
    end

  end

  describe "#logger" do

    it "returns a valid logger" do
      i = instance do; end
      l = i.logger
      l.is_a?(Logger).should eq(true)
    end

  end

  describe "context" do

    it "returns a stored named value" do
      c = Context.new
      c.store :mykey, "myval"
      c.retrieve(:mykey).should eq("myval")
    end

    it "raises KeyError if the stored value does not exist" do
      c = Context.new
      v = c.retrieve(:badkey) 
      expect { Lazy::demand(v) }.to raise_error(Lazy::LazyException)
    end

    it "defers evaluation of a retrieve if store has not been called yet" do
      c = Context.new
      v = c.retrieve(:mykey)
      c.store(:mykey, "myval")
      v.should eq("myval")
    end

  end

end
