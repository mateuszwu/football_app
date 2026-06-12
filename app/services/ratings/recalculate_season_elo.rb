module Ratings
  class RecalculateSeasonElo
    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      elo_map = initial_elo_map

      finished_match_days.each do |match_day|
        finished_matches(match_day).each do |match|
          process_match(match, elo_map)
        end

        apply_vote_bonuses(match_day, elo_map)
      end

      persist(elo_map)
    end

    private

    attr_reader :season

    def initial_elo_map
      Hash.new(season.initial_elo).tap do |map|
        season_players.find_each do |player|
          player_season_stat = InitializePlayerSeasonStat.call(player:, season:)
          map[player.id] = player_season_stat.elo
        end
      end
    end

    def finished_match_days
      season.match_days
            .finished
            .order(:played_on, :id)
    end

    def finished_matches(match_day)
      match_day.matches
               .includes(home_team: :players, away_team: :players)
               .where.not(finished_at: nil)
               .order(:started_at, :id)
    end

    def process_match(match, elo_map)
      Ratings::ProcessMatchElo.call(match:, season:)

      match.home_team.players.each do |player|
        elo_map[player.id] = player.reload.elo
      end

      match.away_team.players.each do |player|
        elo_map[player.id] = player.reload.elo
      end
    end

    def apply_vote_bonuses(match_day, elo_map)
      match_day_votes(match_day).each do |vote|
        elo_map[vote.mvp_player_id] += vote.mvp_bonus
        elo_map[vote.def_player_id] += vote.def_bonus
      end
    end

    def match_day_votes(match_day)
      MatchDayVote
        .joins(match_day_vote_token: { match_day_player: :match_day })
        .where(match_days: { id: match_day.id })
        .includes(:mvp_player, :def_player, match_day_vote_token: { match_day_player: :match_day })
    end

    def persist(elo_map)
      Player.transaction do
        elo_map.each do |player_id, elo|
          Player.where(id: player_id).update_all(elo: elo)
        end
      end
    end

    def season_players
      Player.joins(team_players: { team: { team_setup: :match_day } })
            .where(match_days: { season_id: season.id })
            .distinct
    end
  end
end
