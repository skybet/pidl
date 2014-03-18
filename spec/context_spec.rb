require 'pidl'
require 'lazy'

include Pidl

describe Context do

  describe "Key/Value Store" do

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

    it "returns the whole context has" do
      c = Context.new
      c.store(:mykey, "myval")
      c.store(:myotherkey, "myotherval")
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
