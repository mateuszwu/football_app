require "rails_helper"

RSpec.describe Ratings::ProcessMatchElo do
  describe ".call" do
    it "gives the winning team Elo gains and the losing team Elo losses" do
      season = create(:season, elo_k_value: 16.0)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      home_player = create(:player, elo: 1000)
      away_player = create(:player, elo: 1000)
      create(:team_player, team: home_team, player: home_player)
      create(:team_player, team: away_team, player: away_player)
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, started_at: Time.zone.now, finished_at: Time.zone.now)

      result = described_class.call(match:, season:)

      expect(result).to be(true)
      expect(home_player.reload.elo).to eq(1008)
      expect(away_player.reload.elo).to eq(992)
      expect(home_team.team_players.find_by!(player: home_player).elo_delta).to eq(8)
      expect(away_team.team_players.find_by!(player: away_player).elo_delta).to eq(-8)
      expect(PlayerRatingChange.where(match:).count).to eq(2)
      expect(match.reload.elo_processed_at).to be_present
    end

    it "handles a draw as 0.5 actual score" do
      season = create(:season, elo_k_value: 16.0)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      home_player = create(:player, elo: 1000)
      away_player = create(:player, elo: 1000)
      create(:team_player, team: home_team, player: home_player)
      create(:team_player, team: away_team, player: away_player)
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 1, started_at: Time.zone.now, finished_at: Time.zone.now)

      described_class.call(match:, season:)

      expect(home_player.reload.elo).to eq(1000)
      expect(away_player.reload.elo).to eq(1000)
    end

    it "gives the underdog a larger gain" do
      season = create(:season, elo_k_value: 16.0)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      favored_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      underdog_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      favored_player = create(:player, elo: 1200)
      underdog_player = create(:player, elo: 1000)
      create(:team_player, team: favored_team, player: favored_player)
      create(:team_player, team: underdog_team, player: underdog_player)
      match = create(:match, match_day:, home_team: favored_team, away_team: underdog_team, home_score: 0, away_score: 1, started_at: Time.zone.now, finished_at: Time.zone.now)

      described_class.call(match:, season:)

      expect(underdog_player.reload.elo).to be > 1008
      expect(favored_player.reload.elo).to be < 1192
    end

    it "uses larger-team advantage in the expected score" do
      season = create(:season, elo_k_value: 16.0, player_advantage_elo: 40.0)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      larger_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      smaller_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      larger_players = Array.new(2) { create(:player, elo: 1000) }
      smaller_player = create(:player, elo: 1000)
      larger_players.each { |player| create(:team_player, team: larger_team, player:) }
      create(:team_player, team: smaller_team, player: smaller_player)
      match = create(:match, match_day:, home_team: larger_team, away_team: smaller_team, home_score: 1, away_score: 1, started_at: Time.zone.now, finished_at: Time.zone.now)

      described_class.call(match:, season:)

      expect(larger_players.map { |player| player.reload.elo }).to all(eq(999))
      expect(smaller_player.reload.elo).to eq(1001)
    end

    it "does not process the same match twice" do
      season = create(:season, elo_k_value: 16.0)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      home_player = create(:player, elo: 1000)
      away_player = create(:player, elo: 1000)
      create(:team_player, team: home_team, player: home_player)
      create(:team_player, team: away_team, player: away_player)
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, started_at: Time.zone.now, finished_at: Time.zone.now)

      first_result = described_class.call(match:, season:)
      second_result = described_class.call(match: match.reload, season:)

      expect(first_result).to be(true)
      expect(second_result).to be(false)
      expect(PlayerRatingChange.where(match:).count).to eq(2)
    end
  end
end
