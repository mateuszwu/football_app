require "rails_helper"

RSpec.describe Seasons::PublicLeaderboardQuery do
  describe ".call" do
    it "returns ranked leaderboards using competition ranking" do
      season = create(:season)
      first_player = create(:player, name: "Adam Nowak", approval_status: "approved", active: true)
      second_player = create(:player, name: "Bartek Nowak", approval_status: "approved", active: true)
      third_player = create(:player, name: "Cezary Nowak", approval_status: "approved", active: true)
      match_day = create(:match_day, season:)
      create(:match_day_player, match_day:, player: first_player)
      create(:match_day_player, match_day:, player: second_player)
      create(:match_day_player, match_day:, player: third_player)
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      match = create(
        :match,
        match_day:,
        home_team:,
        away_team:,
        home_score: 3,
        away_score: 1,
        started_at: 1.hour.ago,
        finished_at: 30.minutes.ago
      )
      create(:team_player, team: home_team, player: first_player)
      create(:team_player, team: home_team, player: second_player)
      create(:team_player, team: away_team, player: third_player)
      create(:player_season_stat, season:, player: first_player, goals: 5, assists: 1, mvp_votes_count: 2, def_votes_count: 1, elo: 1100, performance_score: 6.0)
      create(:player_season_stat, season:, player: second_player, goals: 5, assists: 0, mvp_votes_count: 2, def_votes_count: 1, elo: 1100, performance_score: 5.0)
      create(:player_season_stat, season:, player: third_player, goals: 2, assists: 4, mvp_votes_count: 1, def_votes_count: 0, elo: 1000, performance_score: 6.0)
      create(:player_rating_change, player: first_player, season:, match_day:, match:, elo_delta: 12, created_at: 2.hours.ago)
      create(:player_rating_change, player: first_player, season:, match_day:, match:, elo_delta: 18, created_at: 1.hour.ago)

      result = described_class.call(season:)

      expect(result.ranked_top_scorers.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.ranked_top_scorers.map(&:value)).to eq([ 5, 5, 2 ])
      expect(result.ranked_top_mvp.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.ranked_elo.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.ranked_goals_assists.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.ranked_goals_assists.map(&:value)).to eq([ 6, 6, 5 ])
      expect(result.ranked_record.map(&:rank)).to eq([ 1, 1, 3 ])
      expect(result.ranked_record.map(&:value)).to eq([ 100, 100, 0 ])
      expect(result.ranked_elo.first.entry.matches_played_count.to_i).to eq(1)
      expect(result.ranked_elo.first.entry.last_elo_delta_value).to eq(18)
      expect(result.ranked_record.first.entry.wins_count).to eq(1)
      expect(result.ranked_record.last.entry.losses_count).to eq(1)
      expect(result.ranked_record.first.entry.goal_difference_value).to eq(2)
    end
  end
end
