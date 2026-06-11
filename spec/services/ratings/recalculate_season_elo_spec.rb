require "rails_helper"

RSpec.describe Ratings::RecalculateSeasonElo do
  describe ".call" do
    it "recalculates player Elo ratings correctly based on match results in a season" do
      # 1. Arrange: Season with custom initial_elo and elo_k_factor
      season = create(:season, initial_elo: 1000, elo_k_factor: 32)

      # Match day 1 (finished)
      match_day1 = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 1))
      team_setup1 = create(:team_setup, match_day: match_day1)
      team_a = create(:team, team_setup: team_setup1, team_type: "match")
      team_b = create(:team, team_setup: team_setup1, team_type: "match")

      player_a = create(:player)
      player_b = create(:player)
      create(:team_player, team: team_a, player: player_a)
      create(:team_player, team: team_b, player: player_b)

      # Match 1: team_a vs team_b (2-1 home win, so player_a wins, player_b loses)
      create(
        :match,
        match_day: match_day1,
        home_team: team_a,
        away_team: team_b,
        home_score: 2,
        away_score: 1,
        started_at: Time.zone.parse("2026-06-01 18:00:00"),
        finished_at: Time.zone.parse("2026-06-01 18:50:00")
      )

      # Match day 2 (finished)
      match_day2 = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 2))
      team_setup2 = create(:team_setup, match_day: match_day2)
      team_c = create(:team, team_setup: team_setup2, team_type: "match")
      team_d = create(:team, team_setup: team_setup2, team_type: "match")

      # player_a plays again, this time with player_b on the same team vs new player_c
      create(:team_player, team: team_c, player: player_a)
      create(:team_player, team: team_c, player: player_b)
      player_c = create(:player)
      create(:team_player, team: team_d, player: player_c)

      # Match 2: team_c vs team_d (1-1 draw)
      create(
        :match,
        match_day: match_day2,
        home_team: team_c,
        away_team: team_d,
        home_score: 1,
        away_score: 1,
        started_at: Time.zone.parse("2026-06-02 18:00:00"),
        finished_at: Time.zone.parse("2026-06-02 18:50:00")
      )

      # 2. Act: Run the service
      Ratings::RecalculateSeasonElo.call(season: season)

      # 3. Assert: Verify the final computed Elo ratings
      # Let's calculate expected ratings:
      # Match 1: player_a (1000) vs player_b (1000) -> player_a wins.
      # expected_a = 0.5, actual_a = 1.0 -> delta_a = 32 * (1.0 - 0.5) = 16. player_a becomes 1016.
      # expected_b = 0.5, actual_b = 0.0 -> delta_b = 32 * (0.0 - 0.5) = -16. player_b becomes 984.
      #
      # Match 2: Team C (player_a: 1016, player_b: 984 -> avg: 1000) vs Team D (player_c: 1000 -> avg: 1000).
      # Result is 1-1 draw.
      # For player_a:
      # player_elo = 1016, opponent_avg_elo = 1000.
      # expected_a = 1.0 / (1.0 + 10.0**((1000 - 1016) / 400.0)) = 1.0 / (1.0 + 10.0**(-0.04))
      # 10**(-0.04) ≈ 0.91201
      # expected_a = 1.0 / 1.91201 ≈ 0.523
      # delta_a = (32 * (0.5 - 0.523)).round = (32 * -0.023).round = (-0.736).round = -1.
      # new player_a elo = 1016 - 1 = 1015.
      #
      # For player_b:
      # player_elo = 984, opponent_avg_elo = 1000.
      # expected_b = 1.0 / (1.0 + 10.0**((1000 - 984) / 400.0)) = 1.0 / (1.0 + 10.0**0.04)
      # 10**0.04 ≈ 1.096478
      # expected_b = 1.0 / 2.096478 ≈ 0.477
      # delta_b = (32 * (0.5 - 0.477)).round = (32 * 0.023).round = (0.736).round = 1.
      # new player_b elo = 984 + 1 = 985.
      #
      # For player_c:
      # player_elo = 1000, opponent_avg_elo = 1000.
      # expected_c = 0.5
      # delta_c = 32 * (0.5 - 0.5) = 0.
      # new player_c elo = 1000.

      expect(player_a.reload.elo).to eq(1015)
      expect(player_b.reload.elo).to eq(985)
      expect(player_c.reload.elo).to eq(1000)
    end
  end
end
