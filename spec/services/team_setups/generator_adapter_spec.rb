require "rails_helper"

RSpec.describe TeamSetups::GeneratorAdapter do
  describe ".call" do
    it "raises until a concrete adapter implements the interface" do
      expect do
        described_class.call
      end.to raise_error(NotImplementedError, "TeamSetups::GeneratorAdapter must implement #call")
    end
  end
end
