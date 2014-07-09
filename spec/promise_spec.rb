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

    it "accepts a symbol and context and evaluates when requested" do
       context = Context.new
       context.set :symbol, "value"
       p = Promise.new :symbol, context
       p.value.should eq("value")
    end

    it "returns the same value every time after symbol evaluation" do
       context = Context.new
       context.set :symbol, "value"
       p = Promise.new :symbol, context
       p.value.should eq("value")
       context.set :symbol, "different"
       p.value.should eq("value")
    end

    it "evaluates symbols lazily" do
       context = Context.new
       p = Promise.new :symbol, context
       context.set :symbol, "value"
       p.value.should eq("value")
    end

    it "returns the symbol if no context provided" do
      p = Promise.new :symbol
      p.value.should eq(:symbol)
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

    it "evaluates if automatically converted to string" do
      p = Promise.new lambda { "world" }
      a = "hello " << p
      a.should eq("hello world")
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
