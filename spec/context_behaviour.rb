require 'event_behaviour'

shared_examples_for "Context" do
  it_behaves_like "EventEmitter"

  def emitter_instance
    context_instance
  end

  describe "Key/Value Store" do

    it "returns a set named value" do
      c = context_instance
      c.set :mykey, "myval"
      c.get(:mykey).should eq("myval")
    end

    it "returns nil if the set value does not exist" do
      c = context_instance
      v = c.get(:badkey) 
      Lazy::demand(v).should eq(nil)
    end

    it "returns the whole context hash" do
      c = context_instance
      c.set(:mykey, "myval")
      c.set(:myotherkey, "myotherval")
      a = c.all
      a[:mykey].should eq("myval")
      a[:myotherkey].should eq("myotherval")
    end

  end

  describe "custom scalar" do

    it "throws NoMethodError if no value exists" do
      expect do
        c = context_instance
        c.param
      end.to raise_error(NoMethodError)
    end

    it "returns the param if it exists" do
      c = context_instance param: 'this is the param'
      c.param.should eq('this is the param')
    end

  end

  describe "custom array" do

    it "throws NoMethodError if no array exists" do
      expect do
        c = context_instance
        c.params
      end.to raise_error(NoMethodError)
    end

    it "returns empty array if no params exist" do
      c = context_instance params: []
      c.params.should eq([])
    end

    it "returns the params array if params exist" do
      c = context_instance params: ['one', 'two', 'three']
      c.params.should eq(['one', 'two', 'three'])
    end

  end

  describe "custom hash" do

    it "throws NoMethodError if no hash exists" do
      expect do
        c = context_instance
        c.params 'mykey'
      end.to raise_error(NoMethodError)
    end

    it "throws KeyError if key doesn't exist" do
      expect do
        c = context_instance params: { somekey: 'somevalue' }
        c.params 'mykey'
      end.to raise_error(KeyError)
    end

    it "returns the value if the key exists" do
      c = context_instance params: { somekey: 'somevalue' }
      c.params(:somekey).should eq('somevalue')
    end

    it "returns the full hash if all_params is called" do
      c = context_instance params: { somekey: 'somevalue' }
      c.all_params.should eq({ somekey: 'somevalue' })
    end

  end

end

