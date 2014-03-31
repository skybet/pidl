require 'pidl'

include Pidl

describe Promise do

  describe "#value" do

    it "accepts and returns a scalar value" do
      p = Promise.new("hello")
      p.value.should eq("hello")
    end

    it "accepts a lambda and evaluates it when requested" do
      p = Promise.new lambda { "hello" }
      p.value.should eq("hello")
    end

    it "returns the same value every time after lambda evaluation" do
      number = 1
      p = Promise.new lambda { number }
      p.value.should eq(1)

      number = 2
      p.value.should eq(1)
    end

    it "evaluates lambdas lazily" do
      number = 1
      p = Promise.new lambda { number }
      number = 2
      p.value.should eq(2)
    end

    it "accepts a block and evaluates it when requested" do
      p = Promise.new do
        "hello"
      end
      p.value.should eq("hello")
    end

    it "returns the same value every time after block evaluation" do
      number = 1
      p = Promise.new do
        number
      end
      p.value.should eq(1)

      number = 2
      p.value.should eq(1)
    end

    it "evaluates blocks lazily" do
      number = 1
      p = Promise.new do
        number
      end
      number = 2
      p.value.should eq(2)
    end

    it "does not allow a block and a value at the same time" do
      expect do
        Promise.new "hello" do
          "hello"
        end
      end.to raise_error(ArgumentError)
    end

  end

  describe "#to_s" do

    it "evaluates if cast to string" do
      p = Promise.new lambda { "hello" }
      p.to_s.should eq("hello")
    end

    it "evaluates if coerced to string" do
      p = Promise.new lambda { "hello" }
      "#{p}".should eq("hello")
    end

  end

  describe "#evaluated?" do

    it "returns false if not yet evaluated" do
      p = Promise.new lambda { "hello" }
      p.evaluated?.should eq(false)
    end

    it "returns true if evaluated" do
      p = Promise.new lambda { "hello" }
      p.value
      p.evaluated?.should eq(true)
    end

    it "always returns true for simple values" do
      p = Promise.new "hello"
      p.evaluated?.should eq(true)
    end

  end

end
