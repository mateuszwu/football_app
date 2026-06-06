require "rails_helper"

RSpec.describe TeamSetups::CreateMatchTeamsFromBaseline do
  describe ".call" do
    context "when baseline teams exist" do
      it "creates match teams from the baseline teams" do
        team_setup = create(:team_setup)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: "baseline")
        baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: "baseline")
        create(:team_player, team: baseline_team_a, player: first_player)
        create(:team_player, team: baseline_team_b, player: second_player)

        result = described_class.call(team_setup:)

        expect(result).to be(true)
        expect(team_setup.teams.where(team_type: "baseline").count).to eq(2)
        expect(team_setup.teams.where(team_type: "match").count).to eq(2)
        expect(team_setup.teams.find_by!(name: "Team A", team_type: "match").players).to contain_exactly(first_player)
        expect(team_setup.teams.find_by!(name: "Team B", team_type: "match").players).to contain_exactly(second_player)
      end

      it "replaces existing match teams" do
        team_setup = create(:team_setup)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        extra_player = create(:player, name: "Extra", nickname: "extra", phone: "+48999999997")
        baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: "baseline")
        baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: "baseline")
        old_match_team = create(:team, team_setup:, name: "Team A", team_type: "match")
        create(:team_player, team: baseline_team_a, player: first_player)
        create(:team_player, team: baseline_team_b, player: second_player)
        create(:team_player, team: old_match_team, player: extra_player)

        result = described_class.call(team_setup:)

        expect(result).to be(true)
        expect(team_setup.teams.where(team_type: "match").count).to eq(2)
        expect(team_setup.teams.find_by!(name: "Team A", team_type: "match").players).to contain_exactly(first_player)
        expect(team_setup.teams.find_by!(name: "Team B", team_type: "match").players).to contain_exactly(second_player)
        expect(team_setup.teams.where(team_type: "match").flat_map(&:player_ids)).not_to include(extra_player.id)
      end
    end

    context "when baseline teams do not exist" do
      it "returns false without creating match teams" do
        team_setup = create(:team_setup)

        result = described_class.call(team_setup:)

        expect(result).to be(false)
        expect(team_setup.teams.where(team_type: "match")).to be_empty
      end
    end
  end
end
