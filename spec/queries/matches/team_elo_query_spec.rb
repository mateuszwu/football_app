require "rails_helper"

RSpec.describe Matches::TeamEloQuery do
  describe ".call" do
    it "calculates the historical team Elo from player snapshots" do
      season = create(:season)
      match_day = create(:match_day, season:, status: "in_progress")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      home_player = create(:player, elo: 1100)
      second_home_player = create(:player, elo: 900)
      away_player = create(:player, elo: 1000)
      create(:team_player, team: home_team, player: home_player, elo_before: 1100, elo_after: 1110)
      create(:team_player, team: home_team, player: second_home_player, elo_before: 900, elo_after: 910)
      create(:team_player, team: away_team, player: away_player, elo_before: 1000, elo_after: 990)
      match = create(:match, match_day:, home_team:, away_team:)

      result = described_class.call(match:)

      expect(result.fetch(:home)).to eq(
        before: { average: 1000, effective: 1000 },
        after: { average: 1010, effective: 1010 }
      )
      expect(result.fetch(:away)).to eq(
        before: { average: 1000, effective: 1000 },
        after: { average: 990, effective: 990 }
      )
    end

    it "includes the configured player-count advantage in effective Elo" do
      season = create(:season, player_advantage_elo: 40.0)
      match_day = create(:match_day, season:, status: "in_progress")
      team_setup = create(:team_setup, match_day:)
      larger_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      smaller_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      larger_players = Array.new(2) { create(:player, elo: 1000) }
      smaller_player = create(:player, elo: 1000)
      larger_players.each { |player| create(:team_player, team: larger_team, player:, elo_before: 1000, elo_after: 1010) }
      create(:team_player, team: smaller_team, player: smaller_player, elo_before: 1000, elo_after: 990)
      match = create(:match, match_day:, home_team: larger_team, away_team: smaller_team, all_roster_players_on_pitch: true)

      result = described_class.call(match:)

      expect(result.fetch(:home).fetch(:before).fetch(:effective)).to eq(1040)
      expect(result.fetch(:home).fetch(:after).fetch(:effective)).to eq(1050)
      expect(result.fetch(:away).fetch(:before).fetch(:effective)).to eq(1000)
      expect(result.fetch(:away).fetch(:after).fetch(:effective)).to eq(990)
    end

    it "returns empty values when a team has no historical Elo snapshot" do
      season = create(:season)
      match_day = create(:match_day, season:, status: "in_progress")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: home_team, elo_before: nil)
      create(:team_player, team: away_team, elo_before: 1000)
      match = create(:match, match_day:, home_team:, away_team:)

      result = described_class.call(match:)

      expect(result).to eq(home: nil, away: nil)
    end

    it "keeps the before-match value when the match has not been processed yet" do
      season = create(:season)
      match_day = create(:match_day, season:, status: "in_progress")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: home_team, elo_before: 1100)
      create(:team_player, team: away_team, elo_before: 1000)
      match = create(:match, match_day:, home_team:, away_team:)

      result = described_class.call(match:)

      expect(result.fetch(:home)).to eq(before: { average: 1100, effective: 1100 }, after: nil)
      expect(result.fetch(:away)).to eq(before: { average: 1000, effective: 1000 }, after: nil)
    end
  end
end
