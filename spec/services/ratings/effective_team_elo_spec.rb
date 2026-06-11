require "rails_helper"

RSpec.describe Ratings::EffectiveTeamElo do
  describe ".call" do
    context "when the team has players with Elo ratings" do
      it "returns the average Elo across the team" do
        first_player = create(:player)
        second_player = create(:player)
        elo_map = {
          first_player.id => 1040,
          second_player.id => 960
        }

        result = described_class.call(players: [ first_player, second_player ], elo_map: elo_map)

        expect(result).to eq(1000.0)
      end
    end

    context "when the team has no players" do
      it "returns zero" do
        result = described_class.call(players: [], elo_map: {})

        expect(result).to eq(0.0)
      end
    end
  end
end
