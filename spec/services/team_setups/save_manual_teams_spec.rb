require "rails_helper"

RSpec.describe TeamSetups::SaveManualTeams do
  describe ".call" do
    context "when the team assignments are valid" do
      it "creates a baseline team setup with team players" do
        match_day = create(:match_day)
        player_one = create(:player, name: "Player One", role_code: "DEF")
        player_two = create(:player, name: "Player Two", role_code: "MID")

        result = described_class.call(
          match_day: match_day,
          selected_player_ids: [ player_one.id, player_two.id ],
          teams_data: [
            { name: "Team A", player_ids: [ player_one.id.to_s ] },
            { name: "Team B", player_ids: [ player_two.id.to_s ] }
          ]
        )

        expect(result).to be(true)
        expect(match_day.team_setups.count).to eq(1)
        expect(match_day.team_setups.first.setup_method).to eq(TeamSetup::SETUP_METHOD_MANUAL)
        expect(match_day.team_setups.first.accepted_at).to be_present
        expect(match_day.teams.find_by!(name: "Team A").players).to contain_exactly(player_one)
        expect(match_day.teams.find_by!(name: "Team B").players).to contain_exactly(player_two)
        expect(match_day.teams.find_by!(name: "Team A").lineup_source).to eq(Team::LINEUP_SOURCE_MANUAL)
        expect(match_day.teams.find_by!(name: "Team A").team_players.first.player_name).to eq("Player One")
        expect(match_day.teams.find_by!(name: "Team B").team_players.first.role_code).to eq("MID")
      end
    end

    context "when no manual teams are assigned" do
      it "removes existing team setups" do
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day: match_day)
        team = create(:team, team_setup: team_setup, name: "Team A", team_type: "baseline")
        create(:team_player, team: team, player: create(:player))

        result = described_class.call(
          match_day: match_day,
          selected_player_ids: [],
          teams_data: []
        )

        expect(result).to be(true)
        expect(match_day.team_setups.reload).to be_empty
      end
    end

    context "when a player is assigned to more than one team" do
      it "returns false and adds an error" do
        match_day = create(:match_day)
        player = create(:player)

        result = described_class.call(
          match_day: match_day,
          selected_player_ids: [ player.id ],
          teams_data: [
            { name: "Team A", player_ids: [ player.id.to_s ] },
            { name: "Team B", player_ids: [ player.id.to_s ] }
          ]
        )

        expect(result).to be(false)
        expect(match_day.errors[:base]).to include("Player cannot be assigned to more than one manual team")
      end
    end

    context "when a manual team uses a player outside the selected match day players" do
      it "returns false and adds an error" do
        match_day = create(:match_day)
        selected_player = create(:player)
        other_player = create(:player)

        result = described_class.call(
          match_day: match_day,
          selected_player_ids: [ selected_player.id ],
          teams_data: [
            { name: "Team A", player_ids: [ other_player.id.to_s ] }
          ]
        )

        expect(result).to be(false)
        expect(match_day.errors[:base]).to include("Manual teams must use selected match day players only")
      end
    end
  end
end
