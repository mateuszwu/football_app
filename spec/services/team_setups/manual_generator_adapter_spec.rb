require "rails_helper"

RSpec.describe TeamSetups::ManualGeneratorAdapter do
  describe ".call" do
    context "when both teams have assigned players" do
      it "returns normalized baseline team definitions" do
        result = described_class.call(
          team_a_player_ids: [ "2", "1", "2" ],
          team_b_player_ids: [ "4", "3" ]
        )

        expect(result).to eq(
          [
            { name: "Team A", team_type: "baseline", player_ids: [ 2, 1 ] },
            { name: "Team B", team_type: "baseline", player_ids: [ 4, 3 ] }
          ]
        )
      end
    end

    context "when one team has no assigned players" do
      it "omits the empty team" do
        result = described_class.call(
          team_a_player_ids: [ "1" ],
          team_b_player_ids: []
        )

        expect(result).to eq(
          [
            { name: "Team A", team_type: "baseline", player_ids: [ 1 ] }
          ]
        )
      end
    end
  end
end
