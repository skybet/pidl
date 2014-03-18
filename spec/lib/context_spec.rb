require 'pidl'
require 'lazy'

include Pidl

describe Context do

  it "returns the value associated with a requested config key" do
    c = Context.new({ 'some.key' => 'someval' }, {})
    c.config('some.key').should eq('someval')
  end

  it "raises KeyError if the requested config key does not exist" do
    c = Context.new({ 'some.key' => 'someval' }, {})
    expect { c.config('wrong.key') }.to raise_error(KeyError)
  end

  it "returns the value associated with a requested schema key" do
    c = Context.new({}, { 'hive.db.staging' => 'test_staging' })
    c.schema('hive.db.staging').should eq('test_staging')
  end

  it "raises KeyError if the requested schema key does not exist" do
    c = Context.new({}, { 'hive.db.staging' => 'test_staging' })
    expect { c.schema('hive.invalid.db') }.to raise_error(KeyError)
  end

  it "returns a stored named value" do
    c = Context.new({}, {})
    c.store :mykey, "myval"
    c.retrieve(:mykey).should eq("myval")
  end

  it "raises KeyError if the stored value does not exist" do
    c = Context.new({}, {})
    v = c.retrieve(:badkey) 
    expect { Lazy::demand(v) }.to raise_error(Lazy::LazyException)
  end

  it "defers evaluation of a retrieve if store has not been called yet" do
    c = Context.new({}, {})
    v = c.retrieve(:mykey)
    c.store(:mykey, "myval")
    v.should eq("myval")
  end

  it "returns the whole context has" do
    c = Context.new({}, {})
    c.store(:mykey, "myval")
    c.store(:myotherkey, "myotherval")
    c.all.should eq({
      mykey: "myval",
      myotherkey: "myotherval"
    })
  end

end
