require 'logger'

shared_examples_for "Context" do

  describe "Key/Value Store" do

    it "returns a set named value" do
      c = context_instance
      c.set :mykey, "myval"
      c.get(:mykey).should eq("myval")
    end

    it "raises KeyError if the set value does not exist" do
      c = context_instance
      v = c.get(:badkey) 
      expect { Lazy::demand(v) }.to raise_error(Lazy::LazyException)
    end

    it "defers evaluation of a get if set has not been called yet" do
      c = context_instance
      v = c.get(:mykey)
      c.set(:mykey, "myval")
      v.should eq("myval")
    end

    it "returns the whole context has" do
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

  end

end

