require "rails_helper"

RSpec.describe Relationships::RebuildSeasonPairStats do
  describe ".call" do
    it "persists shared days and active finished-match metrics for every pair in one season" do
      season = create(:season, name: "Rebuild Season")
      other_season = create(:season, name: "Ignored Rebuild Season")
      adam = create(:player, name: "Adam Rebuild", nickname: "adam-rebuild", approval_status: "approved", active: true)
      bartek = create(:player, name: "Bartek Rebuild", nickname: "bartek-rebuild", approval_status: "approved", active: true)
      opponent = create(:player, name: "Opponent Rebuild", nickname: "opponent-rebuild", approval_status: "approved", active: true)

      match_day = create(:match_day, season:, played_on: Date.new(2026, 2, 1), status: "finished")
      [ adam, bartek, opponent ].each { |player| create(:match_day_player, match_day:, player:) }
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      adam_team_player = create(:team_player, team: home_team, player: adam)
      bartek_team_player = create(:team_player, team: home_team, player: bartek)
      opponent_team_player = create(:team_player, team: away_team, player: opponent)
      match = create(
        :match,
        match_day:,
        home_team:,
        away_team:,
        home_score: 2,
        away_score: 1,
        started_at: Time.zone.parse("2026-02-01 18:00:00"),
        finished_at: Time.zone.parse("2026-02-01 19:00:00")
      )
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: bartek_team_player)
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player: bartek_team_player, assistant_team_player: adam_team_player)
      create(:match_goal, match:, scoring_team: away_team, scorer_team_player: opponent_team_player)
      create(
        :match_goal,
        match:,
        scoring_team: home_team,
        scorer_team_player: adam_team_player,
        assistant_team_player: bartek_team_player,
        undone_at: Time.current
      )
      create(:match_goal, match:, scoring_team: away_team, scorer_team_player: adam_team_player, own_goal: true)

      shared_day_only = create(:match_day, season:, played_on: Date.new(2026, 2, 8), status: "ready")
      [ adam, bartek ].each { |player| create(:match_day_player, match_day: shared_day_only, player:) }
      ignored_day = create(:match_day, season: other_season, played_on: Date.new(2026, 2, 1), status: "finished")
      [ adam, bartek ].each { |player| create(:match_day_player, match_day: ignored_day, player:) }

      result = described_class.call(season:)

      player_one, player_two = [ adam, bartek ].sort_by(&:id)
      persisted_pair = SeasonPairStat.find_by!(season:, player_one:, player_two:)
      expect(result).to eq(3)
      expect(persisted_pair).to have_attributes(
        shared_match_days_count: 2,
        shared_matches_count: 1,
        wins: 1,
        draws: 0,
        losses: 0,
        goals: 2,
        assists: 2,
        mutual_assists: 2,
        goal_difference: 1
      )
      expect(season.reload.pair_stats_generated_at).to be_present
      expect(other_season.reload.pair_stats_generated_at).to be_nil
    end

    it "replaces stale rows and remains idempotent" do
      season = create(:season)
      adam = create(:player, approval_status: "approved", active: true)
      bartek = create(:player, approval_status: "approved", active: true)
      match_day = create(:match_day, season:, status: "finished")
      [ adam, bartek ].each { |player| create(:match_day_player, match_day:, player:) }

      first_result = described_class.call(season:)
      first_attributes = SeasonPairStat.where(season:).pick(
        :player_one_id,
        :player_two_id,
        :shared_match_days_count,
        :shared_matches_count
      )
      second_result = described_class.call(season:)

      expect(first_result).to eq(1)
      expect(second_result).to eq(1)
      expect(SeasonPairStat.where(season:).count).to eq(1)
      expect(
        SeasonPairStat.where(season:).pick(
          :player_one_id,
          :player_two_id,
          :shared_match_days_count,
          :shared_matches_count
        )
      ).to eq(first_attributes)
    end
  end
end
