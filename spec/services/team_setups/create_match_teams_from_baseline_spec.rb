require "rails_helper"

RSpec.describe TeamSetups::CreateMatchTeamsFromBaseline do
  describe ".call" do
    context "when baseline teams exist" do
      it "creates match teams from the baseline teams" do
        team_setup = create(:team_setup)
        first_player = create(:player, name: "First", role_code: "DEF")
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", role_code: "MID")
        baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE)
        baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE)
        create(:team_player, team: baseline_team_a, player: first_player)
        create(:team_player, team: baseline_team_b, player: second_player)

        result = described_class.call(team_setup:)

        expect(result).to be(true)
        expect(team_setup.teams.where(team_type: Team::TEAM_TYPE_BASELINE).count).to eq(2)
        expect(team_setup.teams.where(team_type: Team::TEAM_TYPE_MATCH).count).to eq(2)
        match_team_a = team_setup.teams.find_by!(name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        match_team_b = team_setup.teams.find_by!(name: "Team B", team_type: Team::TEAM_TYPE_MATCH)

        expect(match_team_a.players).to contain_exactly(first_player)
        expect(match_team_b.players).to contain_exactly(second_player)
        expect(match_team_a.lineup_source).to eq(Team::LINEUP_SOURCE_AUTO)
        expect(match_team_a.source_team).to eq(baseline_team_a)
        expect(match_team_a.team_players.first.player_name).to eq("First")
        expect(match_team_b.team_players.first.role_code).to eq("MID")
      end

      it "replaces existing match teams" do
        team_setup = create(:team_setup)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        extra_player = create(:player, name: "Extra", nickname: "extra", phone: "+48999999997")
        baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE)
        baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE)
        old_match_team = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: baseline_team_a, player: first_player)
        create(:team_player, team: baseline_team_b, player: second_player)
        create(:team_player, team: old_match_team, player: extra_player)

        result = described_class.call(team_setup:)

        expect(result).to be(true)
        expect(team_setup.teams.where(team_type: Team::TEAM_TYPE_MATCH).count).to eq(2)
        expect(team_setup.teams.find_by!(name: "Team A", team_type: Team::TEAM_TYPE_MATCH).players).to contain_exactly(first_player)
        expect(team_setup.teams.find_by!(name: "Team B", team_type: Team::TEAM_TYPE_MATCH).players).to contain_exactly(second_player)
        expect(team_setup.teams.where(team_type: Team::TEAM_TYPE_MATCH).flat_map(&:player_ids)).not_to include(extra_player.id)
      end
    end

    context "when baseline teams do not exist" do
      it "returns false without creating match teams" do
        team_setup = create(:team_setup)

        result = described_class.call(team_setup:)

        expect(result).to be(false)
        expect(team_setup.teams.where(team_type: Team::TEAM_TYPE_MATCH)).to be_empty
      end
    end
  end
end
