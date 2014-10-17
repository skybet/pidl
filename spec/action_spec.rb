require 'pidl'
require 'base_behaviour'

include Pidl

describe Action do
  it_behaves_like "PidlBase"

  def action &block
    return Action.new :actionname, context, &block
  end

  subject(:context) do
    Context.new
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
        expect(a.raise_on_error?).to eq(true)
      end

      it "returns true if on_error is :raise" do
        a = action do
          on_error :raise
        end
        expect(a.raise_on_error?).to eq(true)
      end

      it "returns false if on_error is :exit" do
        a = action do
          on_error :exit
        end
        expect(a.raise_on_error?).to eq(false)
      end

      it "returns false if on_error is :continue" do
        a = action do
          on_error :continue
        end
        expect(a.raise_on_error?).to eq(false)
      end

    end

    describe "#exit_on_error?" do

      it "returns false if on_error is not set" do
        a = action do
        end
        expect(a.exit_on_error?).to eq(false)
      end

      it "returns true if on_error is :exit" do
        a = action do
          on_error :exit
        end
        expect(a.exit_on_error?).to eq(true)
      end

      it "returns false if on_error is :raise" do
        a = action do
          on_error :raise
        end
        expect(a.exit_on_error?).to eq(false)
      end

      it "returns false if on_error is :continue" do
        a = action do
          on_error :continue
        end
        expect(a.exit_on_error?).to eq(false)
      end

    end

  end

  describe "#attributes" do

    context "with absolute attributes" do

      class AttributeAction < Action
        setter :first, :second, :third
      end

      def action &block
        AttributeAction.new :testname, context, &block
      end

      it "returns all attributes" do
        a = action do
          action :test
          first "1st"
          second "2nd"
          third "3rd"
        end
        expect(a.attributes).to eq({
          action: :test,
          first: '1st',
          second: '2nd',
          third: '3rd'
        })
      end

      it "skips missed attributes" do
        a = action do
          action :test
          first "1st"
          third "3rd"
        end
        expect(a.attributes).to eq({
          action: :test,
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
        LazyAttributeAction.new :testname, context, &block
      end

      it "returns all attributes as promises" do
        a = action do
          action :test
          first "1st"
          second "2nd"
          third "3rd"
        end
        expect(Hash[ a.attributes.map { |k, v| [k, k == :action ? v : v.value]} ]).to eq({
          action: :test,
          first: '1st',
          second: '2nd',
          third: '3rd'
        })
      end

      it "evaluates all attributes if true is passed" do
        a = action do
          action :test
          first "1st"
          second "2nd"
          third "3rd"
        end
        expect(a.attributes(true)).to eq({
          action: :test,
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
      SetterAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      expect(a.attributes[:parameter]).to eq(123)
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      expect(a.attributes[:parameter]).to eq(456)
    end

    it "returns a symbol" do
      a = action do
        parameter :symbol
      end
      expect(a.attributes[:parameter]).to eq(:symbol)
    end

    it "returns a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      expect(a.attributes[:parameter].lambda?).to eq(true)
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
      SetterLazyAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      expect(a.attributes[:parameter].value).to eq(123)
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      expect(a.attributes[:parameter].value).to eq(456)
    end

    it "returns the value associated with a symbol in the context" do
      context.set :symbol, 123
      a = action do
        parameter :symbol
      end
      expect(a.attributes[:parameter].value).to eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      expect(a.attributes[:parameter].value).to eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter do
          1
        end
      end
      expect(a.attributes[:parameter].value).to eq(1)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      a = action do
        parameter do
          "#{get(:path)}/filename"
        end
      end
      context.set :path, "/tmp/my/path"
      expect(a.attributes[:parameter].value).to eq("/tmp/my/path/filename")
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
      VargSetterAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value in an array" do
      a = action do
        parameter 123
      end
      expect(a.attributes[:parameter]).to eq([ 123 ])
    end

    it "returns multiple params as an array" do
      a = action do
        parameter 123, "string", ["array"]
      end
      expect(a.attributes[:parameter]).to eq([ 123, "string", ["array"] ])
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      expect(a.attributes[:parameter]).to eq([ 456 ])
    end

    it "returns a symbol in an array" do
      a = action do
        parameter :symbol
      end
      expect(a.attributes[:parameter]).to eq([ :symbol ])
    end

    it "returns a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      expect(a.attributes[:parameter][0].lambda?).to eq(true)
    end

    it "does nothing with a block" do
      a = action do
        parameter do
          1
        end
      end
      expect(a.attributes[:parameter]).to eq([])
    end

  end

  describe "vargsetterlazy" do

    class VargSetterLazyAction < Action
      vargsetterlazy :parameter
    end

    def action &block
      VargSetterLazyAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      expect(a.attributes[:parameter][0].value).to eq(123)
    end

    it "returns multiple params as an array" do
      a = action do
        parameter 123, "string", ["array"]
      end
      expect(a.attributes[:parameter][0].value).to eq(123)
      expect(a.attributes[:parameter][1].value).to eq("string")
      expect(a.attributes[:parameter][2].value).to eq(["array"])
    end

    it "overwrites previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      expect(a.attributes[:parameter][0].value).to eq(456)
    end

    it "returns the value associated with a symbol in the context" do
      context.set :symbol, 123
      a = action do
        parameter :symbol
      end
      expect(a.attributes[:parameter][0].value).to eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      expect(a.attributes[:parameter][0].value).to eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter do
          1
        end
      end
      expect(a.attributes[:parameter][0].value).to eq(1)
    end

    it "puts block at the end of the array" do
      a = action do
        parameter lambda { 1 } do
          2
        end
      end
      expect(a.attributes[:parameter][0].value).to eq(1)
      expect(a.attributes[:parameter][1].value).to eq(2)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      context.set :path, "/tmp/my/path"
      a = action do
        parameter do
          "#{get(:path)}/filename"
        end
      end
      expect(a.attributes[:parameter][0].value).to eq("/tmp/my/path/filename")
    end

  end

  describe "arraysetter" do

    class ArraySetterAction < Action
      arraysetter :parameter
    end

    def action &block
      ArraySetterAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      expect(a.attributes[:parameter]).to eq([ 123 ])
    end

    it "appends to previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      expect(a.attributes[:parameter]).to eq([ 123, 456 ])
    end

    it "returns a symbol" do
      a = action do
        parameter :symbol
      end
      expect(a.attributes[:parameter]).to eq([ :symbol ])
    end

    it "returns a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      expect(a.attributes[:parameter][0].lambda?).to eq(true)
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
      ArraySetterLazyAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter 123
      end
      expect(a.attributes[:parameter][0].value).to eq(123)
    end

    it "appends to previous values" do
      a = action do
        parameter 123
        parameter 456
      end
      expect(a.attributes[:parameter][0].value).to eq(123)
      expect(a.attributes[:parameter][1].value).to eq(456)
    end

    it "returns the value associated with a symbol in the context" do
      context.set :symbol, 123
      a = action do
        parameter :symbol
      end
      expect(a.attributes[:parameter][0].value).to eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter lambda { 1 }
      end
      expect(a.attributes[:parameter][0].value).to eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter do
          1
        end
      end
      expect(a.attributes[:parameter][0].value).to eq(1)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      context.set :path, "/tmp/my/path"
      a = action do
        parameter do
          "#{get(:path)}/filename"
        end
      end
      expect(a.attributes[:parameter][0].value).to eq("/tmp/my/path/filename")
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
      HashSetterAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter :test, 123
      end
      expect(a.attributes[:parameter]).to eq({ test: 123 })
    end

    it "overwrites previous values" do
      a = action do
        parameter :one, 123
        parameter :one, 456
      end
      expect(a.attributes[:parameter]).to eq({ one: 456 })
    end

    it "adds multiple values" do
      a = action do
        parameter :one, 1
        parameter :two, 2
      end
      expect(a.attributes[:parameter]).to eq({ one: 1, two: 2 })
    end

    it "returns a symbol" do
      a = action do
        parameter :test, :symbol
      end
      expect(a.attributes[:parameter]).to eq({ test: :symbol })
    end

    it "returns a lambda" do
      a = action do
        parameter :one, lambda { 1 }
      end
      expect(a.attributes[:parameter][:one].lambda?).to eq(true)
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
      HashSetterLazyAction.new :testname, context, &block
    end

    it "returns nil if not set" do
      a = action do; end
      expect(a.attributes[:parameter]).to eq(nil)
    end

    it "returns a scalar value" do
      a = action do
        parameter :test, 123
      end
      expect(a.attributes[:parameter][:test].value).to eq(123)
    end

    it "overwrites previous values" do
      a = action do
        parameter :one, 123
        parameter :one, 456
      end
      expect(a.attributes[:parameter][:one].value).to eq(456)
    end

    it "adds multiple values" do
      a = action do
        parameter :one, 1
        parameter :two, 2
      end
      expect(a.attributes[:parameter][:one].value).to eq(1)
      expect(a.attributes[:parameter][:two].value).to eq(2)
    end

    it "returns the value associated with a symbol in the context" do
      context.set :symbol, 123
      a = action do
        parameter :test, :symbol
      end
      expect(a.attributes[:parameter][:test].value).to eq(123)
    end

    it "evaluates a lambda" do
      a = action do
        parameter :test, lambda { 1 }
      end
      expect(a.attributes[:parameter][:test].value).to eq(1)
    end

    it "evaluates a block" do
      a = action do
        parameter :test do
          1
        end
      end
      expect(a.attributes[:parameter][:test].value).to eq(1)
    end

    it "recursively evaluates context calls inside lazy blocks" do
      a = action do
        parameter :test do
          "#{get(:path)}/filename"
        end
      end
      context.set :path, "/tmp/my/path"
      expect(a.attributes[:parameter][:test].value).to eq("/tmp/my/path/filename")
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

