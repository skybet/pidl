shared_examples_for "EventEmitter" do

  context "events" do

    it "raises an error if handler is not callable" do
      expect do
        subject.on :test, "not callable"
      end.to raise_error(ArgumentError)
    end

    context "with a single listener" do

      let(:probe) { lambda {} }

      it "receives an event if the listener is a block" do
        expect(probe).to receive(:call).with(:test)
        subject.on :test, &probe
        subject.emit :test
      end

      it "receives an event if the listener is a lambda" do
        expect(probe).to receive(:call).with(:test)
        subject.on :test, probe
        subject.emit :test
      end

      it "raises an error if both a lambda and block is provided" do
        expect do
          subject.on :test, probe do; end
        end.to raise_error(ArgumentError)
      end

      it "sends parameters via emit" do
        expect(probe).to receive(:call).with(:test, 'a', 1)

        subject.on :test, &probe
        subject.emit :test, 'a', 1
      end

    end

    context "with multiple listeners" do

      let(:probe1) { lambda{} }
      let(:probe2) { lambda{} }

      it "subscribes multiple listeners and all receive an event" do
        expect(probe1).to receive(:call).with(:test)
        expect(probe2).to receive(:call).with(:test)

        subject.on :test, &probe1
        subject.on :test, &probe2
        subject.emit :test
      end

      it "sends parameters to all subscribers via emit" do
        expect(probe1).to receive(:call).with(:test, 'a', 1)
        expect(probe2).to receive(:call).with(:test, 'a', 1)

        subject.on :test, &probe1
        subject.on :test, &probe2
        subject.emit :test, 'a', 1
      end

      it "unsubscribes on required" do
        expect(probe1).not_to receive :call
        expect(probe2).to receive :call

        subject.on :test, &probe1
        subject.on :test, &probe2

        subject.removeListener :test, probe1

        subject.emit :test
      end

    end

  end

end


