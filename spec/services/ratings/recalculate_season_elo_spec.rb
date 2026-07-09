require "rails_helper"

RSpec.describe Ratings::RecalculateSeasonElo do
  describe ".call" do
    it "recalculates player Elo ratings correctly based on match results in a season" do
      season = create(:season, initial_elo: 1000, elo_k_factor: 32)
      match_day1 = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 1))
      team_setup1 = create(:team_setup, match_day: match_day1)
      team_a = create(:team, team_setup: team_setup1, team_type: "match")
      team_b = create(:team, team_setup: team_setup1, team_type: "match")
      player_a = create(:player)
      player_b = create(:player)
      create(:team_player, team: team_a, player: player_a)
      create(:team_player, team: team_b, player: player_b)
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
      match_day2 = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 2))
      team_setup2 = create(:team_setup, match_day: match_day2)
      team_c = create(:team, team_setup: team_setup2, team_type: "match")
      team_d = create(:team, team_setup: team_setup2, team_type: "match")
      create(:team_player, team: team_c, player: player_a)
      create(:team_player, team: team_c, player: player_b)
      player_c = create(:player)
      player_d = create(:player)
      create(:team_player, team: team_d, player: player_c)
      create(:team_player, team: team_d, player: player_d)
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

      Ratings::RecalculateSeasonElo.call(season: season)

      # Let's calculate expected ratings:
      # Match 1: player_a (1000) vs player_b (1000) -> player_a wins.
      # expected_a = 0.5, actual_a = 1.0 -> delta_a = 16 * (1.0 - 0.5) = 8. player_a becomes 1008.
      # expected_b = 0.5, actual_b = 0.0 -> delta_b = 16 * (0.0 - 0.5) = -8. player_b becomes 992.
      #
      # Match 2: Team C (player_a: 1008, player_b: 992 -> avg: 1000) vs Team D (player_c: 1000, player_d: 1000 -> avg: 1000).
      # Result is 1-1 draw.
      # Both teams have the same effective Elo, so the draw produces no change.

      expect(player_a.reload.elo).to eq(1008)
      expect(player_b.reload.elo).to eq(992)
      expect(player_c.reload.elo).to eq(1000)
      expect(player_d.reload.elo).to eq(1000)
    end

    it "does not change Elo from MVP and DEF votes" do
      season = create(:season, initial_elo: 1000, elo_k_factor: 32, mvp_max_points: 4.0, def_max_points: 3.0, voting_bonus_cap: 5.0, expected_voters_count: 5)
      match_day = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 3))
      team_setup = create(:team_setup, match_day: match_day)
      team_a = create(:team, team_setup: team_setup, team_type: "match")
      team_b = create(:team, team_setup: team_setup, team_type: "match")
      voter = create(:player, name: "Voter")
      mvp_winner = create(:player, name: "MVP Winner")
      def_winner = create(:player, name: "DEF Winner")
      away_support = create(:player, name: "Away Support")
      create(:team_player, team: team_a, player: voter)
      create(:team_player, team: team_a, player: mvp_winner)
      create(:team_player, team: team_b, player: def_winner)
      create(:team_player, team: team_b, player: away_support)
      voter_match_day_player = create(:match_day_player, match_day: match_day, player: voter)
      create(:match_day_player, match_day: match_day, player: mvp_winner)
      create(:match_day_player, match_day: match_day, player: def_winner)
      vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player)
      MatchDayVote.create!(match_day_vote_token: vote_token, mvp_player: mvp_winner, def_player: def_winner)
      create(
        :match,
        match_day: match_day,
        home_team: team_a,
        away_team: team_b,
        home_score: 1,
        away_score: 1,
        started_at: Time.zone.parse("2026-06-03 18:00:00"),
        finished_at: Time.zone.parse("2026-06-03 18:50:00")
      )

      Ratings::RecalculateSeasonElo.call(season: season)

      expect(voter.reload.elo).to eq(1000)
      expect(mvp_winner.reload.elo).to eq(1000)
      expect(def_winner.reload.elo).to eq(1000)
      expect(away_support.reload.elo).to eq(1000)
      expect(PlayerSeasonStat.find_by!(player: mvp_winner, season: season).elo).to eq(1000)
      expect(PlayerSeasonStat.find_by!(player: def_winner, season: season).elo).to eq(1000)
      expect(season.reload.elo_recalculated_at).to be_present
    end

    it "initializes season Elo from existing global Elo with the carryover factor and stores season stats" do
      season = create(:season, initial_elo: 1000, elo_k_factor: 32)
      match_day = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 4))
      team_setup = create(:team_setup, match_day: match_day)
      team_a = create(:team, team_setup: team_setup, team_type: "match")
      team_b = create(:team, team_setup: team_setup, team_type: "match")
      player_a = create(:player, elo: 1200)
      player_b = create(:player, elo: 1000)
      create(:team_player, team: team_a, player: player_a)
      create(:team_player, team: team_b, player: player_b)
      create(
        :match,
        match_day: match_day,
        home_team: team_a,
        away_team: team_b,
        home_score: 1,
        away_score: 0,
        started_at: Time.zone.parse("2026-06-04 18:00:00"),
        finished_at: Time.zone.parse("2026-06-04 18:50:00")
      )

      Ratings::RecalculateSeasonElo.call(season: season)

      expect(player_a.reload.elo).to eq(1106)
      expect(player_b.reload.elo).to eq(994)
      expect(PlayerSeasonStat.find_by!(player: player_a, season: season).elo).to eq(1106)
      expect(PlayerSeasonStat.find_by!(player: player_b, season: season).elo).to eq(994)
    end

    it "applies a 40 Elo advantage for each extra player" do
      season = create(:season, initial_elo: 1000, elo_k_factor: 32)
      match_day = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 5))
      team_setup = create(:team_setup, match_day: match_day)
      team_a = create(:team, team_setup: team_setup, team_type: "match")
      team_b = create(:team, team_setup: team_setup, team_type: "match")
      home_player_one = create(:player)
      home_player_two = create(:player)
      away_player = create(:player)
      create(:team_player, team: team_a, player: home_player_one)
      create(:team_player, team: team_a, player: home_player_two)
      create(:team_player, team: team_b, player: away_player)

      create(
        :match,
        match_day: match_day,
        home_team: team_a,
        away_team: team_b,
        home_score: 1,
        away_score: 1,
        started_at: Time.zone.parse("2026-06-05 18:00:00"),
        finished_at: Time.zone.parse("2026-06-05 18:50:00")
      )

      Ratings::RecalculateSeasonElo.call(season: season)

      expect(home_player_one.reload.elo).to eq(999)
      expect(home_player_two.reload.elo).to eq(999)
      expect(away_player.reload.elo).to eq(1001)
    end

    it "rebuilds Elo even when a match was processed before and keeps match order stable by created_at fallback" do
      season = create(:season, initial_elo: 1000, elo_k_value: 16.0)
      match_day = create(:match_day, season: season, status: "finished", played_on: Date.new(2026, 6, 6))
      team_setup = create(:team_setup, match_day: match_day)
      team_a = create(:team, team_setup: team_setup, team_type: Team::TEAM_TYPE_MATCH)
      team_b = create(:team, team_setup: team_setup, team_type: Team::TEAM_TYPE_MATCH)
      team_c = create(:team, team_setup: team_setup, team_type: Team::TEAM_TYPE_MATCH)
      team_d = create(:team, team_setup: team_setup, team_type: Team::TEAM_TYPE_MATCH)
      player_a = create(:player, elo: 1300)
      player_b = create(:player, elo: 1000)
      create(:team_player, team: team_a, player: player_a)
      create(:team_player, team: team_b, player: player_b)
      create(:team_player, team: team_c, player: player_a)
      create(:team_player, team: team_d, player: player_b)
      first_match = create(:match, match_day: match_day, home_team: team_a, away_team: team_b, home_score: 1, away_score: 0, started_at: nil, finished_at: Time.zone.parse("2026-06-06 18:50:00"), created_at: Time.zone.parse("2026-06-06 18:00:00"))
      second_match = create(:match, match_day: match_day, home_team: team_c, away_team: team_d, home_score: 0, away_score: 1, started_at: nil, finished_at: Time.zone.parse("2026-06-06 19:50:00"), created_at: Time.zone.parse("2026-06-06 19:00:00"))

      Ratings::ProcessMatchElo.call(match: first_match, season: season)
      player_a.update!(elo: 1500)
      player_b.update!(elo: 900)

      Ratings::RecalculateSeasonElo.call(season: season)

      expect(player_a.reload.elo).to eq(1238)
      expect(player_b.reload.elo).to eq(962)
      expect(PlayerRatingChange.where(season: season, source_type: PlayerRatingChange::SOURCE_TYPE_MATCH).count).to eq(4)
      expect(first_match.reload.elo_processed_at).to be_present
      expect(second_match.reload.elo_processed_at).to be_present
    end

    it "preserves goals, assists, votes, and performance statistics" do
      season = create(:season, initial_elo: 1000, elo_k_value: 16.0)
      match_day = create(:match_day, season:, status: "finished", played_on: Date.new(2026, 6, 7))
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
      home_player = create(:player)
      away_player = create(:player)
      create(:team_player, team: home_team, player: home_player)
      create(:team_player, team: away_team, player: away_player)
      create(
        :match,
        match_day:,
        home_team:,
        away_team:,
        home_score: 1,
        away_score: 0,
        started_at: Time.zone.parse("2026-06-07 18:00:00"),
        finished_at: Time.zone.parse("2026-06-07 18:50:00")
      )
      create(
        :player_season_stat,
        season:,
        player: home_player,
        goals: 3,
        assists: 2,
        mvp_votes_count: 4,
        def_votes_count: 1,
        performance_score: 5.5
      )

      described_class.call(season:)

      recalculated_stat = PlayerSeasonStat.find_by!(season:, player: home_player)

      expect(recalculated_stat.attributes.symbolize_keys).to include(
        goals: 3,
        assists: 2,
        mvp_votes_count: 4,
        def_votes_count: 1,
        performance_score: BigDecimal("5.5")
      )
    end
  end
end
