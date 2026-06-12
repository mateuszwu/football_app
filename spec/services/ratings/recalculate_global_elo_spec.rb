require "rails_helper"

RSpec.describe Ratings::RecalculateGlobalElo do
  describe ".call" do
    it "rebuilds global Elo season by season using each season's stored settings" do
      player = create(:player, elo: 1400)
      opponent = create(:player, elo: 1400)

      season_one = create(:season, name: "Season One", starts_on: Date.new(2026, 1, 1), elo_k_value: 16.0)
      match_day_one = create(:match_day, season: season_one, status: "finished", played_on: Date.new(2026, 1, 10))
      team_setup_one = create(:team_setup, match_day: match_day_one)
      season_one_home = create(:team, team_setup: team_setup_one, team_type: Team::TEAM_TYPE_MATCH)
      season_one_away = create(:team, team_setup: team_setup_one, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: season_one_home, player:)
      create(:team_player, team: season_one_away, player: opponent)
      create(:match, match_day: match_day_one, home_team: season_one_home, away_team: season_one_away, home_score: 1, away_score: 0, started_at: Time.zone.parse("2026-01-10 18:00:00"), finished_at: Time.zone.parse("2026-01-10 18:50:00"))

      season_two = create(:season, name: "Season Two", starts_on: Date.new(2026, 2, 1), elo_k_value: 32.0, season_elo_carryover_factor: 1.0)
      match_day_two = create(:match_day, season: season_two, status: "finished", played_on: Date.new(2026, 2, 10))
      team_setup_two = create(:team_setup, match_day: match_day_two)
      season_two_home = create(:team, team_setup: team_setup_two, team_type: Team::TEAM_TYPE_MATCH)
      season_two_away = create(:team, team_setup: team_setup_two, team_type: Team::TEAM_TYPE_MATCH)
      create(:team_player, team: season_two_home, player:)
      create(:team_player, team: season_two_away, player: opponent)
      create(:match, match_day: match_day_two, home_team: season_two_home, away_team: season_two_away, home_score: 1, away_score: 0, started_at: Time.zone.parse("2026-02-10 18:00:00"), finished_at: Time.zone.parse("2026-02-10 18:50:00"))

      described_class.call

      expect(player.reload.elo).to eq(1023)
      expect(opponent.reload.elo).to eq(977)
      expect(PlayerSeasonStat.find_by!(player:, season: season_one).elo).to eq(1008)
      expect(PlayerSeasonStat.find_by!(player:, season: season_two).elo).to eq(1023)
      expect(season_one.reload.elo_recalculated_at).to be_present
      expect(season_two.reload.elo_recalculated_at).to be_present
    end
  end
end
