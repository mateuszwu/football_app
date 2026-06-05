require "rails_helper"

RSpec.describe TeamSetups::GenerateFingerprint do
  describe ".call" do
    context "when two setups have the same team composition" do
      it "returns the same fingerprint regardless of insertion order" do
        first_setup = create(:team_setup)
        second_setup = create(:team_setup)
        player_one = create(:player)
        player_two = create(:player)
        player_three = create(:player)

        first_blue = create(:team, team_setup: first_setup, name: "Blue", team_type: "baseline")
        first_red = create(:team, team_setup: first_setup, name: "Red", team_type: "baseline")
        create(:team_player, team: first_red, player: player_three)
        create(:team_player, team: first_blue, player: player_two)
        create(:team_player, team: first_blue, player: player_one)

        second_red = create(:team, team_setup: second_setup, name: "Red", team_type: "baseline")
        second_blue = create(:team, team_setup: second_setup, name: "Blue", team_type: "baseline")
        create(:team_player, team: second_blue, player: player_one)
        create(:team_player, team: second_blue, player: player_two)
        create(:team_player, team: second_red, player: player_three)

        first_fingerprint = described_class.call(team_setup: first_setup)
        second_fingerprint = described_class.call(team_setup: second_setup)

        expect(first_fingerprint).to eq(second_fingerprint)
      end
    end

    context "when team composition changes" do
      it "returns a different fingerprint" do
        team_setup = create(:team_setup)
        other_team_setup = create(:team_setup)
        shared_player = create(:player)
        original_player = create(:player)
        replacement_player = create(:player)

        original_team = create(:team, team_setup: team_setup, name: "Blue", team_type: "baseline")
        create(:team_player, team: original_team, player: shared_player)
        create(:team_player, team: original_team, player: original_player)

        changed_team = create(:team, team_setup: other_team_setup, name: "Blue", team_type: "baseline")
        create(:team_player, team: changed_team, player: shared_player)
        create(:team_player, team: changed_team, player: replacement_player)

        original_fingerprint = described_class.call(team_setup:)
        changed_fingerprint = described_class.call(team_setup: other_team_setup)

        expect(original_fingerprint).not_to eq(changed_fingerprint)
      end
    end
  end
end
