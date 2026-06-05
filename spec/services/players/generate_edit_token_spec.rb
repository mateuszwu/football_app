require "rails_helper"

RSpec.describe Players::GenerateEditToken do
  describe ".call" do
    it "returns a JWT with player id and a 6 hour expiration" do
      player = create(:player)

      token = described_class.call(player: player)
      payload, = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: described_class::ALGORITHM)

      expect(payload["player_id"]).to eq(player.id)
      expect(payload["exp"]).to be_within(5).of(described_class::EXPIRATION.from_now.to_i)
    end
  end
end
