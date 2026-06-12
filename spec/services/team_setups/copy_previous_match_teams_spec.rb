require "rails_helper"

RSpec.describe TeamSetups::CopyPreviousMatchTeams do
  describe ".call" do
    context "when a previous match day in the same season has match teams" do
      it "copies those match teams to the current match day" do
        season = create(:season)
        previous_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5))
        current_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 12))
        first_player = create(:player, name: "First", role_code: "DEF")
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", role_code: "MID")
        previous_team_setup = create(:team_setup, match_day: previous_match_day)
        previous_team_a = create(:team, team_setup: previous_team_setup, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        previous_team_b = create(:team, team_setup: previous_team_setup, name: "Team B", team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: previous_team_a, player: first_player)
        create(:team_player, team: previous_team_b, player: second_player)

        result = described_class.call(match_day: current_match_day)

        expect(result).to be(true)
        expect(current_match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH).count).to eq(2)
        copied_team_a = current_match_day.teams.find_by!(name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        copied_team_b = current_match_day.teams.find_by!(name: "Team B", team_type: Team::TEAM_TYPE_MATCH)

        expect(copied_team_a.players).to contain_exactly(first_player)
        expect(copied_team_b.players).to contain_exactly(second_player)
        expect(copied_team_a.lineup_source).to eq(Team::LINEUP_SOURCE_COPIED)
        expect(copied_team_a.source_team).to eq(previous_team_a)
        expect(copied_team_a.team_players.first.player_name).to eq("First")
        expect(copied_team_b.team_players.first.role_code).to eq("MID")
        expect(current_match_day.team_setups.first.setup_method).to eq(TeamSetup::SETUP_METHOD_COPIED)
      end

      it "replaces existing match teams on the current match day" do
        season = create(:season)
        previous_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5))
        current_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 12))
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        extra_player = create(:player, name: "Extra", nickname: "extra", phone: "+48999999997")
        previous_team_setup = create(:team_setup, match_day: previous_match_day)
        current_team_setup = create(:team_setup, match_day: current_match_day)
        previous_team_a = create(:team, team_setup: previous_team_setup, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        previous_team_b = create(:team, team_setup: previous_team_setup, name: "Team B", team_type: Team::TEAM_TYPE_MATCH)
        stale_match_team = create(:team, team_setup: current_team_setup, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: previous_team_a, player: first_player)
        create(:team_player, team: previous_team_b, player: second_player)
        create(:team_player, team: stale_match_team, player: extra_player)

        result = described_class.call(match_day: current_match_day)

        expect(result).to be(true)
        expect(current_match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH).count).to eq(2)
        expect(current_match_day.teams.find_by!(name: "Team A", team_type: Team::TEAM_TYPE_MATCH).players).to contain_exactly(first_player)
        expect(current_match_day.teams.find_by!(name: "Team B", team_type: Team::TEAM_TYPE_MATCH).players).to contain_exactly(second_player)
        expect(current_match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH).flat_map(&:player_ids)).not_to include(extra_player.id)
      end
    end

    context "when the previous match day belongs to a different season" do
      it "does not copy its match teams" do
        previous_match_day = create(:match_day, season: create(:season, name: "Old Season"), played_on: Date.new(2026, 6, 5))
        current_match_day = create(:match_day, season: create(:season, name: "New Season"), played_on: Date.new(2026, 6, 12))
        previous_team_setup = create(:team_setup, match_day: previous_match_day)
        previous_team = create(:team, team_setup: previous_team_setup, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: previous_team, player: create(:player))

        result = described_class.call(match_day: current_match_day)

        expect(result).to be(false)
        expect(current_match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH)).to be_empty
      end
    end

    context "when there is no previous match day with match teams" do
      it "returns false without creating match teams" do
        season = create(:season)
        current_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 12))

        result = described_class.call(match_day: current_match_day)

        expect(result).to be(false)
        expect(current_match_day.teams.where(team_type: Team::TEAM_TYPE_MATCH)).to be_empty
      end
    end
  end
end
