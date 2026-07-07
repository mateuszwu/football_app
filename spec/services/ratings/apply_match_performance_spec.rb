require "rails_helper"

RSpec.describe Ratings::ApplyMatchPerformance do
  describe ".call" do
    it "applies goal and assist points to season and global performance totals" do
      season = create(:season, goal_points: 1.5, assist_points: 0.9)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      scorer = create(:player, global_performance_score: 0.0)
      assistant = create(:player, global_performance_score: 0.0)
      opponent = create(:player, global_performance_score: 0.0)
      scorer_team_player = create(:team_player, team: home_team, player: scorer)
      assistant_team_player = create(:team_player, team: home_team, player: assistant)
      create(:team_player, team: away_team, player: opponent)
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, started_at: Time.zone.now, finished_at: Time.zone.now)
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, assistant_team_player:, scored_at: Time.zone.now)

      result = described_class.call(match:, season:)

      expect(result).to be(true)
      expect(PlayerSeasonStat.find_by!(player: scorer, season: season).attributes.slice("goals", "assists", "performance_score")).to eq(
        "goals" => 1,
        "assists" => 0,
        "performance_score" => BigDecimal("1.5")
      )
      expect(PlayerSeasonStat.find_by!(player: assistant, season: season).attributes.slice("goals", "assists", "performance_score")).to eq(
        "goals" => 0,
        "assists" => 1,
        "performance_score" => BigDecimal("0.9")
      )
      expect(scorer.reload.global_performance_score).to eq(BigDecimal("1.5"))
      expect(assistant.reload.global_performance_score).to eq(BigDecimal("0.9"))
      expect(opponent.reload.global_performance_score).to eq(BigDecimal("0.0"))
      expect(PlayerRatingChange.where(match:).count).to eq(2)
      expect(PlayerRatingChange.find_by!(player: scorer, match:, source_type: PlayerRatingChange::SOURCE_TYPE_GOAL).attributes.slice("match_day_id", "rating_scope", "reason", "performance_delta")).to eq(
        "match_day_id" => match_day.id,
        "rating_scope" => PlayerRatingChange::RATING_SCOPE_SEASON,
        "reason" => "goal_performance",
        "performance_delta" => BigDecimal("1.5")
      )
      expect(PlayerRatingChange.find_by!(player: assistant, match:, source_type: PlayerRatingChange::SOURCE_TYPE_ASSIST).performance_delta).to eq(BigDecimal("0.9"))
      expect(match.reload.performance_processed_at).to be_present
    end

    it "ignores undone goals" do
      season = create(:season, goal_points: 1.0, assist_points: 0.8)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      scorer = create(:player, global_performance_score: 0.0)
      assistant = create(:player, global_performance_score: 0.0)
      scorer_team_player = create(:team_player, team: home_team, player: scorer)
      assistant_team_player = create(:team_player, team: home_team, player: assistant)
      create(:team_player, team: away_team, player: create(:player, global_performance_score: 0.0))
      match = create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 0, started_at: Time.zone.now, finished_at: Time.zone.now)
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, scored_at: 2.minutes.ago)
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, assistant_team_player:, scored_at: 1.minute.ago, undone_at: Time.zone.now)

      described_class.call(match:, season:)

      expect(PlayerSeasonStat.find_by!(player: scorer, season: season).goals).to eq(1)
      expect(PlayerSeasonStat.find_by!(player: scorer, season: season).performance_score).to eq(BigDecimal("1.0"))
      expect(PlayerSeasonStat.find_by(player: assistant, season: season)).to be_nil
      expect(PlayerRatingChange.where(match:).count).to eq(1)
    end

    it "does not award goal or assist performance for own goals" do
      season = create(:season, goal_points: 1.0, assist_points: 0.8)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      scorer = create(:player, global_performance_score: 0.0)
      scorer_team_player = create(:team_player, team: away_team, player: scorer)
      create(:team_player, team: home_team, player: create(:player, global_performance_score: 0.0))
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, started_at: Time.zone.now, finished_at: Time.zone.now)
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, own_goal: true, scored_at: Time.zone.now)

      described_class.call(match:, season:)

      expect(PlayerSeasonStat.find_by(player: scorer, season: season)).to be_nil
      expect(scorer.reload.global_performance_score).to eq(BigDecimal("0.0"))
      expect(PlayerRatingChange.where(match:)).to be_empty
    end

    it "does not create assist points for unassisted goals" do
      season = create(:season, goal_points: 1.0, assist_points: 0.8)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      scorer = create(:player, global_performance_score: 0.0)
      scorer_team_player = create(:team_player, team: home_team, player: scorer)
      create(:team_player, team: away_team, player: create(:player, global_performance_score: 0.0))
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, started_at: Time.zone.now, finished_at: Time.zone.now)
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, scored_at: Time.zone.now)

      described_class.call(match:, season:)

      expect(PlayerSeasonStat.find_by!(player: scorer, season: season).attributes.slice("goals", "assists")).to eq(
        "goals" => 1,
        "assists" => 0
      )
      expect(PlayerRatingChange.where(match:, source_type: PlayerRatingChange::SOURCE_TYPE_ASSIST)).to be_empty
    end

    it "does not process the same match twice" do
      season = create(:season, goal_points: 1.0, assist_points: 0.8)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      scorer = create(:player, global_performance_score: 0.0)
      scorer_team_player = create(:team_player, team: home_team, player: scorer)
      create(:team_player, team: away_team, player: create(:player, global_performance_score: 0.0))
      match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, started_at: Time.zone.now, finished_at: Time.zone.now)
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, scored_at: Time.zone.now)

      first_result = described_class.call(match:, season:)
      second_result = described_class.call(match: match.reload, season:)

      expect(first_result).to be(true)
      expect(second_result).to be(false)
      expect(PlayerSeasonStat.find_by!(player: scorer, season: season).performance_score).to eq(BigDecimal("1.0"))
      expect(PlayerRatingChange.where(match:).count).to eq(1)
    end
  end
end
