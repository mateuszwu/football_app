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

    it "does not rank MVP or DEF leaders without votes" do
      season = create(:season)
      player = create(:player, name: "Kuba Bratek", approval_status: "approved", active: true)
      create(:player_season_stat, season:, player:, mvp_votes_count: 0, def_votes_count: 0)

      result = described_class.call(season:)

      expect(result.ranked_top_mvp).to eq([])
      expect(result.ranked_top_def).to eq([])
    end

    it "uses the default 25% attendance and includes the exact threshold" do
      season = create(:season)
      threshold_player = create(:player, name: "At Threshold", approval_status: "approved", active: true)
      below_threshold_player = create(:player, name: "Below Threshold", approval_status: "approved", active: true)

      10.times do |index|
        match_day = create(:match_day, season:, played_on: Date.new(2026, 1, 1) + index)
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:match, match_day:, home_team:, away_team:, started_at: 1.hour.ago, finished_at: 30.minutes.ago)
        create(:team_player, team: home_team, player: threshold_player) if index < 2
        create(:team_player, team: away_team, player: below_threshold_player) if index.zero?
      end

      create(:player_season_stat, season:, player: threshold_player, goals: 5, assists: 3)
      create(:player_season_stat, season:, player: below_threshold_player, goals: 10, assists: 10)

      result = described_class.call(season:)

      expect(result.attendance_percent).to eq(25)
      expect(result.season_matches_count).to eq(10)
      expect(result.minimum_matches).to eq(2)
      expect(result.top_scorers.map { |stat| stat.player.name }).to eq([ "At Threshold" ])
      expect(result.top_assistants.map { |stat| stat.player.name }).to eq([ "At Threshold" ])
      expect(result.goals_assists_ranking.map { |stat| stat.player.name }).to eq([ "At Threshold" ])
    end

    it "shows all offensive ranking players when attendance is 0%" do
      season = create(:season)
      player = create(:player, name: "No Appearance", approval_status: "approved", active: true)
      match_day = create(:match_day, season:)
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      create(:match, match_day:, home_team:, away_team:, started_at: 1.hour.ago, finished_at: 30.minutes.ago)
      create(:player_season_stat, season:, player:, goals: 2, assists: 1)

      result = described_class.call(season:, attendance_percent: 0)

      expect(result.minimum_matches).to eq(0)
      expect(result.top_scorers.map { |stat| stat.player.name }).to include("No Appearance")
      expect(result.top_assistants.map { |stat| stat.player.name }).to include("No Appearance")
      expect(result.goals_assists_ranking.map { |stat| stat.player.name }).to include("No Appearance")
    end

    it "sets the minimum to zero for a season without matches" do
      season = create(:season)
      player = create(:player, name: "No Matches", approval_status: "approved", active: true)
      create(:player_season_stat, season:, player:, goals: 2, assists: 1)

      result = described_class.call(season:)

      expect(result.season_matches_count).to eq(0)
      expect(result.minimum_matches).to eq(0)
      expect(result.top_scorers.map { |stat| stat.player.name }).to eq([ "No Matches" ])
    end

    it "clamps attendance values to the 0 to 100 range" do
      expect(described_class.normalize_attendance_percent(-10)).to eq(0)
      expect(described_class.normalize_attendance_percent(150)).to eq(100)
      expect(described_class.normalize_attendance_percent("invalid")).to eq(25)
    end
  end
end
