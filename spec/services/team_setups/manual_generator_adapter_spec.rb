require "rails_helper"

RSpec.describe TeamSetups::ManualGeneratorAdapter do
  describe ".call" do
    context "when both teams have assigned players" do
      it "returns normalized baseline team definitions" do
        result = described_class.call(
          teams_data: [
            { name: "Team A", player_ids: [ "2", "1", "2" ] },
            { name: "Team B", player_ids: [ "4", "3" ] }
          ]
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
          teams_data: [
            { name: "Team A", player_ids: [ "1" ] },
            { name: "Team B", player_ids: [] }
          ]
        )

        expect(result).to eq(
          [
            { name: "Team A", team_type: "baseline", player_ids: [ 1 ] }
          ]
        )
      end
    end

    context "when a team captain is assigned" do
      it "keeps the captain when the player belongs to the team" do
        result = described_class.call(
          teams_data: [
            { name: "Team A", player_ids: [ "1", "2" ], captain_id: "2" }
          ]
        )

        expect(result).to eq(
          [
            { name: "Team A", team_type: "baseline", player_ids: [ 1, 2 ], captain_id: 2 }
          ]
        )
      end

      it "omits the captain when the player does not belong to the team" do
        result = described_class.call(
          teams_data: [
            { name: "Team A", player_ids: [ "1", "2" ], captain_id: "3" }
          ]
        )

        expect(result).to eq(
          [
            { name: "Team A", team_type: "baseline", player_ids: [ 1, 2 ] }
          ]
        )
      end
    end
  end
end
