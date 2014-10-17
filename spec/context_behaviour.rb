shared_examples_for "Context" do

  describe "Key/Value Store" do

    describe "#get" do
      it "returns a set named value" do
        subject.set :mykey, "myval"
        expect(subject.get(:mykey)).to eq("myval")
      end

      it "returns nil if the set value does not exist" do
        v = subject.get(:badkey) 
        expect(v).to eq(nil)
      end
    end

    describe "#is_set?" do
      it "returns true if a value exists" do
        subject.set :mykey, "myval"
        expect(subject.is_set?(:mykey)).to eq(true)
      end

      it "returns false if a value does not exist" do
        expect(subject.is_set?(:mykey)).to eq(false)
      end

      it "returns false if a value exists but is nil" do
        subject.set :mykey, nil
        expect(subject.is_set?(:mykey)).to eq(false)
      end
    end

    describe "#all" do
      it "returns the whole context hash" do
        subject.set(:mykey, "myval")
        subject.set(:myotherkey, "myotherval")
        a = subject.all
        expect(a[:mykey]).to eq("myval")
        expect(a[:myotherkey]).to eq("myotherval")
      end
    end

  end

  describe "custom scalar" do

    it "throws NoMethodError if no value exists" do
      expect do
        subject.param
      end.to raise_error(NoMethodError)
    end

    context "with a scalar" do
      subject(:context) do
        Context.new param: "this is the param"
      end
      it "returns the param if it exists" do
        expect(subject.param).to eq('this is the param')
      end
    end

  end

  describe "custom array" do

    it "throws NoMethodError if no array exists" do
      expect do
        subject.params
      end.to raise_error(NoMethodError)
    end

    context 'with an array' do

      context 'that is empty' do
        subject(:context) do
          Context.new params: []
        end
        it "returns empty array if no params exist" do
          expect(subject.params).to eq([])
        end
      end

      context 'that is not empty' do
        subject(:context) do
          Context.new params: ['one', 'two', 'three']
        end
        it "returns the params array if params exist" do
          expect(subject.params).to eq(['one', 'two', 'three'])
        end
      end

    end

  end

  describe "custom hash" do

    it "throws NoMethodError if no hash exists" do
      expect do
        subject.params 'mykey'
      end.to raise_error(NoMethodError)
    end

    context "with a hash" do

      subject(:context) do
        Context.new params: { somekey: 'somevalue' }
      end

      it "throws KeyError if key doesn't exist" do
        expect do
          subject.params 'mykey'
        end.to raise_error(KeyError)
      end

      it "returns the value if the key exists" do
        expect(subject.params(:somekey)).to eq('somevalue')
      end

      it "returns the full hash if all_params is called" do
        expect(subject.all_params).to eq({ somekey: 'somevalue' })
      end

    end

  end

end

