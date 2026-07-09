require "rails_helper"

RSpec.describe PlayerIdentity do
  describe ".icons" do
    it "does not include reserved application icons" do
      expect(described_class.icons & described_class.reserved_app_icons).to be_empty
    end
  end

  describe ".valid_icon?" do
    context "when the icon is reserved for the application" do
      it "returns false" do
        expect(described_class.valid_icon?("trophy")).to be(false)
      end
    end
  end

  describe ".safe_icon" do
    context "when the icon is available to players" do
      it "returns the icon" do
        expect(described_class.safe_icon("sun")).to eq("sun")
      end
    end

    context "when the icon is reserved for the application" do
      it "returns the fallback icon" do
        expect(described_class.safe_icon("shield")).to eq("user-round")
      end
    end

    context "when the icon is unknown" do
      it "returns the fallback icon" do
        expect(described_class.safe_icon("spaceship")).to eq("user-round")
      end
    end
  end
end
