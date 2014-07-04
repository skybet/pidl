require 'pidl'
require 'base_behaviour'

include Pidl

describe Action do
  it_behaves_like "PidlBase"

  @context = nil

  def action &block
    return Action.new :actionname, @context, &block
  end

  before(:each) do
    @context = Context.new
  end

  describe "#on_error" do

    it "raises an error on invalid value" do
      expect do
        a = action do
          on_error :explode
        end
      end.to raise_error
    end

    describe "#raise_on_error?" do

      it "returns true if on_error is not set" do
        a = action do
        end
        a.raise_on_error?.should eq(true)
      end

      it "returns true if on_error is :raise" do
        a = action do
          on_error :raise
        end
        a.raise_on_error?.should eq(true)
      end

      it "returns false if on_error is :exit" do
        a = action do
          on_error :exit
        end
        a.raise_on_error?.should eq(false)
      end

      it "returns false if on_error is :continue" do
        a = action do
          on_error :continue
        end
        a.raise_on_error?.should eq(false)
      end

    end

    describe "#exit_on_error?" do

      it "returns false if on_error is not set" do
        a = action do
        end
        a.exit_on_error?.should eq(false)
      end

      it "returns true if on_error is :exit" do
        a = action do
          on_error :exit
        end
        a.exit_on_error?.should eq(true)
      end

      it "returns false if on_error is :raise" do
        a = action do
          on_error :raise
        end
        a.exit_on_error?.should eq(false)
      end

      it "returns false if on_error is :continue" do
        a = action do
          on_error :continue
        end
        a.exit_on_error?.should eq(false)
      end

    end

  end

  describe "#attributes" do

    context "with absolute attributes" do

      class AttributeAction < Action
        setter :first, :second, :third
      end

      def action &block
        AttributeAction.new :testname, @context, &block
      end

      it "returns all attributes" do
        a = action do
          first "1st"
          second "2nd"
          third "3rd"
        end
        a.attributes.should eq({
          first: '1st',
          second: '2nd',
          third: '3rd'
        })
      end

      it "skips missed attributes" do
        a = action do
          first "1st"
          third "3rd"
        end
        a.attributes.should eq({
          first: '1st',
          third: '3rd'
        })
      end

    end

    context "with lazy attributes" do

      class LazyAttributeAction < Action
        setterlazy :first, :second, :third
      end

      def action &block
        LazyAttributeAction.new :testname, @context, &block
      end

      it "returns all attributes as promises" do
        a = action do
          first "1st"
          second "2nd"
          third "3rd"
        end
        Hash[ a.attributes.map { |k, v| [k, v.value]} ].should eq({
          first: '1st',
          second: '2nd',
          third: '3rd'
        })
      end

      it "evaluates all attributes if true is passed" do
        a = action do
          first "1st"
          second "2nd"
          third "3rd"
        end
        a.attributes(true).should eq({
          first: '1st',
          second: '2nd',
          third: '3rd'
        })
      end

    end

  end

  describe "setter" do

    class SetterAction < Action
      setter :parameter
    end

    def action &block
      SetterAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      a.attributes[:parameter].should eq(123)
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      a.attributes[:parameter].should eq(456)
    end

    it "returns a symbol" do
      a = action do
        parameter :symbol
      end
      a.attributes[:parameter].should eq(:symbol)
    end

    it "returns a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      a.attributes[:parameter].lambda?.should eq(true)
    end

    it "does nothing with a block" do
      expect do
        a = action do
          parameter do
            1
          end
        end
      end.to raise_error
    end

  end

  describe "setterlazy" do

    class SetterLazyAction < Action
      setterlazy :parameter
    end

    def action &block
      SetterLazyAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      a.attributes[:parameter].value.should eq(123)
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      a.attributes[:parameter].value.should eq(456)
    end

    it "returns the value associated with a symbol in the context" do
      @context.set :symbol, 123
      a = action do
        parameter :symbol
      end
      a.attributes[:parameter].value.should eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      a.attributes[:parameter].value.should eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter do
          1
        end
      end
      a.attributes[:parameter].value.should eq(1)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      a = action do
        parameter do
          "#{get(:path)}/filename"
        end
      end
      @context.set :path, "/tmp/my/path"
      a.attributes[:parameter].value.should eq("/tmp/my/path/filename")
    end

    it "does not accept a parameter and a block" do
      expect do
        a = action do
          parameter 1 do
            2
          end
        end
      end.to raise_error
    end

  end

  describe "vargsetter" do

    class VargSetterAction < Action
      vargsetter :parameter
    end

    def action &block
      VargSetterAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value in an array" do
      a = action do
        parameter 123
      end
      a.attributes[:parameter].should eq([ 123 ])
    end

    it "returns multiple params as an array" do
      a = action do
        parameter 123, "string", ["array"]
      end
      a.attributes[:parameter].should eq([ 123, "string", ["array"] ])
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      a.attributes[:parameter].should eq([ 456 ])
    end

    it "returns a symbol in an array" do
      a = action do
        parameter :symbol
      end
      a.attributes[:parameter].should eq([ :symbol ])
    end

    it "returns a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      a.attributes[:parameter][0].lambda?.should eq(true)
    end

    it "does nothing with a block" do
      a = action do
        parameter do
          1
        end
      end
      a.attributes[:parameter].should eq([])
    end

  end

  describe "vargsetterlazy" do

    class VargSetterLazyAction < Action
      vargsetterlazy :parameter
    end

    def action &block
      VargSetterLazyAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      a.attributes[:parameter][0].value.should eq(123)
    end

    it "returns multiple params as an array" do
      a = action do
        parameter 123, "string", ["array"]
      end
      a.attributes[:parameter][0].value.should eq(123)
      a.attributes[:parameter][1].value.should eq("string")
      a.attributes[:parameter][2].value.should eq(["array"])
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      a.attributes[:parameter][0].value.should eq(456)
    end

    it "returns the value associated with a symbol in the context" do
      @context.set :symbol, 123
      a = action do
        parameter :symbol
      end
      a.attributes[:parameter][0].value.should eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      a.attributes[:parameter][0].value.should eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter do
          1
        end
      end
      a.attributes[:parameter][0].value.should eq(1)
    end

    it "puts block at the end of the array" do
      a = action do
        parameter lambda { 1 } do
          2
        end
      end
      a.attributes[:parameter][0].value.should eq(1)
      a.attributes[:parameter][1].value.should eq(2)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      @context.set :path, "/tmp/my/path"
      a = action do
        parameter do
          "#{get(:path)}/filename"
        end
      end
      a.attributes[:parameter][0].value.should eq("/tmp/my/path/filename")
    end

  end

  describe "arraysetter" do

    class ArraySetterAction < Action
      arraysetter :parameter
    end

    def action &block
      ArraySetterAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      a.attributes[:parameter].should eq([ 123 ])
    end

    it "appends to previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      a.attributes[:parameter].should eq([ 123, 456 ])
    end

    it "returns a symbol" do
      a = action do
        parameter :symbol
      end
      a.attributes[:parameter].should eq([ :symbol ])
    end

    it "returns a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      a.attributes[:parameter][0].lambda?.should eq(true)
    end

    it "does nothing with a block" do
      expect do
        a = action do
          parameter do
            1
          end
        end
      end.to raise_error
    end

  end

  describe "arraysetterlazy" do

    class ArraySetterLazyAction < Action
      arraysetterlazy :parameter
    end

    def action &block
      ArraySetterLazyAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      a.attributes[:parameter][0].value.should eq(123)
    end

    it "appends to previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      a.attributes[:parameter][0].value.should eq(123)
      a.attributes[:parameter][1].value.should eq(456)
    end

    it "returns the value associated with a symbol in the context" do
      @context.set :symbol, 123
      a = action do
        parameter :symbol
      end
      a.attributes[:parameter][0].value.should eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      a.attributes[:parameter][0].value.should eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter do
          1
        end
      end
      a.attributes[:parameter][0].value.should eq(1)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      @context.set :path, "/tmp/my/path"
      a = action do
        parameter do
          "#{get(:path)}/filename"
        end
      end
      a.attributes[:parameter][0].value.should eq("/tmp/my/path/filename")
    end

    it "does not accept a parameter and a block" do
      expect do
        a = action do
          parameter 1 do
            2
          end
        end
      end.to raise_error
    end

  end

  describe "hashsetter" do

    class HashSetterAction < Action
      hashsetter :parameter
    end

    def action &block
      HashSetterAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter :test, 123
      end
      a.attributes[:parameter].should eq({ test: 123 })
    end

    it "overwrites previous values" do
      a = action do
        parameter :one, 123
        parameter :one, 456
      end
      a.attributes[:parameter].should eq({ one: 456 })
    end

    it "adds multiple values" do
      a = action do
        parameter :one, 1
        parameter :two, 2
      end
      a.attributes[:parameter].should eq({ one: 1, two: 2 })
    end

    it "returns a symbol" do
      a = action do
        parameter :test, :symbol
      end
      a.attributes[:parameter].should eq({ test: :symbol })
    end

    it "returns a lambda" do
      a = action do
        parameter :one, lambda { 1 }
      end
      a.attributes[:parameter][:one].lambda?.should eq(true)
    end

    it "does nothing with a block" do
      expect do
        a = action do
          parameter do
            1
          end
        end
      end.to raise_error
    end

  end

  describe "hashsetterlazy" do

    class HashSetterLazyAction < Action
      hashsetterlazy :parameter
    end

    def action &block
      HashSetterLazyAction.new :testname, @context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      a.attributes[:parameter].should eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter :test, 123
      end
      a.attributes[:parameter][:test].value.should eq(123)
    end

    it "overwrites previous values" do
      a = action do
        parameter :one, 123
        parameter :one, 456
      end
      a.attributes[:parameter][:one].value.should eq(456)
    end

    it "adds multiple values" do
      a = action do
        parameter :one, 1
        parameter :two, 2
      end
      a.attributes[:parameter][:one].value.should eq(1)
      a.attributes[:parameter][:two].value.should eq(2)
    end

    it "returns the value associated with a symbol in the context" do
      @context.set :symbol, 123
      a = action do
        parameter :test, :symbol
      end
      a.attributes[:parameter][:test].value.should eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter :test, lambda { 1 }
      end
      a.attributes[:parameter][:test].value.should eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter :test do
          1
        end
      end
      a.attributes[:parameter][:test].value.should eq(1)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      a = action do
        parameter :test do
          "#{get(:path)}/filename"
        end
      end
      @context.set :path, "/tmp/my/path"
      a.attributes[:parameter][:test].value.should eq("/tmp/my/path/filename")
    end

    it "does not accept a parameter and a block" do
      expect do
        a = action do
          parameter :test, 1 do
            2
          end
        end
      end.to raise_error
    end

  end

end

