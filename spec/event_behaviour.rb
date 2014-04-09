shared_examples_for "EventEmitter" do

  describe "events" do

    it "subscribes a single listener and receives an event" do
      e = emitter_instance
      probe = lambda { }
      probe.should_receive :call

      e.on :test, &probe
      e.emit :test
    end

    it "subscribes multiple listeners and all receive an event" do
      e = emitter_instance
      probe1 = lambda {}
      probe1.should_receive :call
      probe2 = lambda {}
      probe2.should_receive :call

      e.on :test, &probe1
      e.on :test, &probe2
      e.emit :test
    end

    it "sends parameters via emit" do
      e = emitter_instance
      probe = lambda { }
      probe.should_receive(:call).with('a', 1)

      e.on :test, &probe
      e.emit :test, 'a', 1
    end

    it "sends parameters to all subscribers via emit" do
      e = emitter_instance
      probe1 = lambda {}
      probe1.should_receive(:call).with('a', 1)
      probe2 = lambda {}
      probe2.should_receive(:call).with('a', 1)

      e.on :test, &probe1
      e.on :test, &probe2
      e.emit :test, 'a', 1
    end

    it "unsubscribes on required" do
      e = emitter_instance
      probe1 = lambda {}
      probe1.should_not_receive :call
      probe2 = lambda {}
      probe2.should_receive :call

      e.on :test, &probe1
      e.on :test, &probe2
      e.removeListener :test, probe1
      e.emit :test
    end

  end

end


