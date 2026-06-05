require "rails_helper"

RSpec.describe Players::DecodeEditToken do
  describe ".call" do
    context "when the token is valid" do
      it "returns the decoded payload" do
        player = create(:player)
        token = Players::GenerateEditToken.call(player: player)

        result = described_class.call(token: token)

        expect(result["player_id"]).to eq(player.id)
        expect(result["exp"]).to be_present
      end
    end

    context "when the token is invalid" do
      it "returns nil" do
        result = described_class.call(token: "not-a-token")

        expect(result).to be_nil
      end
    end
  end
end
