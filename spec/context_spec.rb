require 'pidl'
require 'lazy'

include Pidl

describe Context do

  describe "Key/Value Store" do

    it "returns a set named value" do
      c = Context.new
      c.set :mykey, "myval"
      c.get(:mykey).should eq("myval")
    end

    it "raises KeyError if the set value does not exist" do
      c = Context.new
      v = c.get(:badkey) 
      expect { Lazy::demand(v) }.to raise_error(Lazy::LazyException)
    end

    it "defers evaluation of a get if set has not been called yet" do
      c = Context.new
      v = c.get(:mykey)
      c.set(:mykey, "myval")
      v.should eq("myval")
    end

    it "returns the whole context has" do
      c = Context.new
      c.set(:mykey, "myval")
      c.set(:myotherkey, "myotherval")
      c.all.should eq({
        mykey: "myval",
        myotherkey: "myotherval"
      })
    end

  end

  describe "params" do

    it "returns empty array if no params exist" do
      c = Context.new
      c.params.should eq([])
    end

    it "returns the params array if params exist" do
      c = Context.new params: ['one', 'two', 'three']
      c.params.should eq(['one', 'two', 'three'])
    end

  end

end
