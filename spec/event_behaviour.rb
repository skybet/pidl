shared_examples_for "EventEmitter" do

  context "events" do

    it "raises an error if handler is not callable" do
      expect do
        subject.on :test, "not callable"
      end.to raise_error
    end

    context "with a single listener" do

      let(:probe) { lambda {} }

      it "receives an event if the listener is a block" do
        probe.should_receive(:call).with(:test)
        subject.on :test, &probe
        subject.emit :test
      end

      it "receives an event if the listener is a lambda" do
        probe.should_receive(:call).with(:test)
        subject.on :test, probe
        subject.emit :test
      end

      it "raises an error if both a lambda and block is provided" do
        expect do
          subject.on :test, probe do; end
        end.to raise_error
      end

      it "sends parameters via emit" do
        probe.should_receive(:call).with(:test, 'a', 1)

        subject.on :test, &probe
        subject.emit :test, 'a', 1
      end

    end

    context "with multiple listeners" do

      let(:probe1) { lambda{} }
      let(:probe2) { lambda{} }

      it "subscribes multiple listeners and all receive an event" do
        probe1.should_receive(:call).with(:test)
        probe2.should_receive(:call).with(:test)

        subject.on :test, &probe1
        subject.on :test, &probe2
        subject.emit :test
      end

      it "sends parameters to all subscribers via emit" do
        probe1.should_receive(:call).with(:test, 'a', 1)
        probe2.should_receive(:call).with(:test, 'a', 1)

        subject.on :test, &probe1
        subject.on :test, &probe2
        subject.emit :test, 'a', 1
      end

      it "unsubscribes on required" do
        probe1.should_not_receive :call
        probe2.should_receive :call

        subject.on :test, &probe1
        subject.on :test, &probe2

        subject.removeListener :test, probe1

        subject.emit :test
      end

    end

  end

end


