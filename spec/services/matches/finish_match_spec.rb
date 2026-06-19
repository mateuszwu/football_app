require "rails_helper"

RSpec.describe Matches::FinishMatch do
  describe ".call" do
    it "applies match performance when the match is finished" do
      season = create(:season, goal_points: 1.2, assist_points: 0.7)
      match_day = create(:match_day, season:, status: "in_progress")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      scorer = create(:player, global_performance_score: 0.0)
      assistant = create(:player, global_performance_score: 0.0)
      scorer_team_player = create(:team_player, team: home_team, player: scorer)
      assistant_team_player = create(:team_player, team: home_team, player: assistant)
      create(:team_player, team: away_team, player: create(:player, global_performance_score: 0.0))
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, started_at: Time.zone.parse("2026-06-12 19:00:00"))
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, assistant_team_player:, scored_at: Time.zone.parse("2026-06-12 19:10:00"))

      result = described_class.call(match:, finished_at: Time.zone.parse("2026-06-12 19:50:00"))

      expect(result).to be(true)
      expect(match.reload.performance_processed_at).to be_present
      expect(PlayerSeasonStat.find_by!(player: scorer, season: season).performance_score).to eq(BigDecimal("1.2"))
      expect(PlayerSeasonStat.find_by!(player: assistant, season: season).performance_score).to eq(BigDecimal("0.7"))
    end

    it "stores loss and win results when the away team wins" do
      match_day = create(:match_day, status: "in_progress")
      match = create(
        :match,
        match_day:,
        home_score: 0,
        away_score: 2,
        started_at: Time.zone.parse("2026-06-12 19:00:00")
      )

      result = described_class.call(match:, finished_at: Time.zone.parse("2026-06-12 19:50:00"))

      expect(result).to be(true)
      expect(match.home_team.reload.result).to eq(Team::RESULT_LOSS)
      expect(match.away_team.reload.result).to eq(Team::RESULT_WIN)
    end

    it "returns false when finishing would violate match day status transitions" do
      match_day = create(:match_day, status: "setup")
      match = create(
        :match,
        match_day:,
        started_at: Time.zone.parse("2026-06-12 19:00:00")
      )

      result = described_class.call(match:, finished_at: Time.zone.parse("2026-06-12 19:50:00"))

      expect(result).to be(false)
      expect(match.reload.finished_at).to be_nil
      expect(match_day.reload.status).to eq("setup")
    end
  end
end
