require 'logger'
require 'context_behaviour'
require 'event_behaviour'

shared_examples_for "PidlBase" do
  it_behaves_like "Context"
  it_behaves_like "EventEmitter"

  let(:block) { Proc.new {} }

  subject(:context) do
    Context.new
  end

  subject do
    described_class.new :name_of_instance, context, &block
  end

  describe "#name" do

    it "returns the specified name" do
      expect(subject.name).to eq(:name_of_instance)
    end

  end

  describe "#logger" do

    it "returns a valid logger" do
      expect(subject.logger).to be_kind_of(Logger)
    end

  end

  describe "#skip?" do

    context "with no condition" do
      it "returns false" do
        expect(subject.skip?).to eq(false)
      end
    end

    context "with true condition" do
      let(:block) {
        Proc.new do
          only_if { true }
        end
      }
      it "returns false" do
        expect(subject.skip?).to eq(false)
      end
    end

    context "with false condition" do
      let(:block) {
        Proc.new do
          only_if { false }
        end
      }
      it "returns true" do
        expect(subject.skip?).to eq(true)
      end
    end

    context "with a symbol" do
      let(:block) {
        Proc.new do
          only_if :mykey
        end
      }

      context "that is not in context" do
        it "returns true" do
          expect(subject.skip?).to eq(true)
        end
      end

      context "that is in context" do
        context "with a truthy value" do
          before do
            subject.set :mykey, "truthy"
          end

          it "returns false" do
            expect(subject.skip?).to eq(false)
          end
        end

        context "with a falsey value" do
          before do
            subject.set :mykey, false
          end

          it "returns true" do
            expect(subject.skip?).to eq(true)
          end
        end
      end
    end

  end

end
