module Ratings
  class ProcessMatchElo
    def self.call(match:, season: match.match_day.season)
      new(match:, season:).call
    end

    def initialize(match:, season:)
      @match = match
      @season = season
    end

    def call
      return false unless processable_match?

      Match.transaction do
        home_result = CalculateTeamElo.call(players: home_players, opponent_players: away_players, elo_map: elo_map, season: season)
        away_result = CalculateTeamElo.call(players: away_players, opponent_players: home_players, elo_map: elo_map, season: season)

        apply_team_delta(match.home_team, home_players, away_result.effective_elo, match_score(match.home_team), home_result.effective_elo)
        apply_team_delta(match.away_team, away_players, home_result.effective_elo, match_score(match.away_team), away_result.effective_elo)

        match.update!(elo_processed_at: Time.current)
      end

      true
    end

    private

    attr_reader :match, :season

    def processable_match?
      return false if match.elo_processed_at.present?
      return false unless match.finished?
      return false unless playing_teams.size == 2
      return false if home_players.empty? || away_players.empty?

      true
    end

    def playing_teams
      @playing_teams ||= [ match.home_team, match.away_team ].select(&:playing?)
    end

    def home_players
      @home_players ||= match.home_team.players.to_a
    end

    def away_players
      @away_players ||= match.away_team.players.to_a
    end

    def elo_map
      @elo_map ||= season_players.index_by(&:id).transform_values do |player|
        Ratings::InitializePlayerSeasonStat.call(player:, season:).elo
      end
    end

    def season_players
      (home_players + away_players).uniq
    end

    def match_score(team)
      if match.draw?
        0.5
      elsif match.winner == team
        1.0
      else
        0.0
      end
    end

    def apply_team_delta(team, players, opponent_effective_elo, actual_score, team_effective_elo)
      expected_score = 1.0 / (1.0 + 10.0**((opponent_effective_elo - team_effective_elo) / 400.0))
      delta = (season.elo_k_value * (actual_score - expected_score)).round

      players.each do |player|
        player_season_stat = Ratings::InitializePlayerSeasonStat.call(player:, season:)
        elo_before = player_season_stat.elo
        elo_after = elo_before + delta
        team_player = team.team_players.find_by!(player:)

        team_player.update!(elo_before:, elo_after:, elo_delta: delta)
        player_season_stat.update!(elo: elo_after)
        player.update!(elo: elo_after)
        Ratings::RecordPlayerRatingChange.call(
          player:,
          season:,
          match_day: match.match_day,
          match:,
          rating_scope: PlayerRatingChange::RATING_SCOPE_SEASON,
          source_type: PlayerRatingChange::SOURCE_TYPE_MATCH,
          reason: "match_elo",
          old_elo_score: elo_before,
          elo_delta: delta,
          new_elo_score: elo_after,
          elo_k_value: season.elo_k_value,
          player_advantage_elo: season.player_advantage_elo
        )
      end
    end
  end
end
