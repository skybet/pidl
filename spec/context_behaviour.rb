require 'event_behaviour'

shared_examples_for "Context" do

  describe "Key/Value Store" do

    describe "#get" do
      it "returns a set named value" do
        c = context_instance
        c.set :mykey, "myval"
        expect(c.get(:mykey)).to eq("myval")
      end

      it "returns nil if the set value does not exist" do
        c = context_instance
        v = c.get(:badkey) 
        expect(Lazy::demand(v)).to eq(nil)
      end
    end

    describe "#is_set?" do
      it "returns true if a value exists" do
        c = context_instance
        c.set :mykey, "myval"
        expect(c.is_set?(:mykey)).to eq(true)
      end

      it "returns false if a value does not exist" do
        c = context_instance
        expect(c.is_set?(:mykey)).to eq(false)
      end

      it "returns false if a value exists but is nil" do
        c = context_instance
        c.set :mykey, nil
        expect(c.is_set?(:mykey)).to eq(false)
      end
    end

    describe "#all" do
      it "returns the whole context hash" do
        c = context_instance
        c.set(:mykey, "myval")
        c.set(:myotherkey, "myotherval")
        a = c.all
        expect(a[:mykey]).to eq("myval")
        expect(a[:myotherkey]).to eq("myotherval")
      end
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
      expect(c.param).to eq('this is the param')
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
      expect(c.params).to eq([])
    end

    it "returns the params array if params exist" do
      c = context_instance params: ['one', 'two', 'three']
      expect(c.params).to eq(['one', 'two', 'three'])
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
      expect(c.params(:somekey)).to eq('somevalue')
    end

    it "returns the full hash if all_params is called" do
      c = context_instance params: { somekey: 'somevalue' }
      expect(c.all_params).to eq({ somekey: 'somevalue' })
    end

  end

end

