shared_examples_for "EventEmitter" do

  describe "events" do

    it "subscribes a single listener and receives an event" do
      e = emitter_instance
      probe = lambda { }
      expect(probe).to receive(:call).with(:test)

      e.on :test, &probe
      e.emit :test
    end

    it "subscribes a single listener with a lambda and receives an event" do
      e = emitter_instance
      probe = lambda { }
      expect(probe).to receive(:call).with(:test)

      e.on :test, probe
      e.emit :test
    end

    it "raises an error if a lambda and block is provided" do
      e = emitter_instance
      probe = lambda { }

      expect do
        e.on :test, probe do; end
      end.to raise_error
    end

    it "raises an error if handler is not callable" do
      e = emitter_instance
      probe = "test"

      expect do
        e.on :test, probe
      end.to raise_error
    end

    it "subscribes multiple listeners and all receive an event" do
      e = emitter_instance
      probe1 = lambda {}
      expect(probe1).to receive(:call).with(:test)
      probe2 = lambda {}
      expect(probe2).to receive(:call).with(:test)

      e.on :test, &probe1
      e.on :test, &probe2
      e.emit :test
    end

    it "sends parameters via emit" do
      e = emitter_instance
      probe = lambda { }
      expect(probe).to receive(:call).with(:test, 'a', 1)

      e.on :test, &probe
      e.emit :test, 'a', 1
    end

    it "sends parameters to all subscribers via emit" do
      e = emitter_instance
      probe1 = lambda {}
      expect(probe1).to receive(:call).with(:test, 'a', 1)
      probe2 = lambda {}
      expect(probe2).to receive(:call).with(:test, 'a', 1)

      e.on :test, &probe1
      e.on :test, &probe2
      e.emit :test, 'a', 1
    end

    it "unsubscribes on required" do
      e = emitter_instance
      probe1 = lambda {}
      expect(probe1).to_not receive :call
      probe2 = lambda {}
      expect(probe2).to receive :call

      e.on :test, &probe1
      e.on :test, &probe2

      e.removeListener :test, probe1

      e.emit :test
    end

  end

end


