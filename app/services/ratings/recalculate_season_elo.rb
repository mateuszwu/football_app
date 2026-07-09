module Ratings
  class RecalculateSeasonElo
    PRESERVED_STAT_COLUMNS = %i[
      goals
      assists
      mvp_votes_count
      def_votes_count
      performance_score
    ].freeze

    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      preserved_stats = preserved_stats_by_player_id
      reset_recalculation_state!

      elo_map = initial_elo_map

      finished_match_days.each do |match_day|
        finished_matches(match_day).each do |match|
          process_match(match, elo_map)
        end
      end

      persist(elo_map)
      restore_preserved_stats!(preserved_stats)
      season.update!(elo_recalculated_at: Time.current)
    end

    private

    attr_reader :season

    def reset_recalculation_state!
      season.player_season_stats.delete_all
      season.player_rating_changes.where(source_type: PlayerRatingChange::SOURCE_TYPE_MATCH).delete_all
    end

    def preserved_stats_by_player_id
      PlayerSeasonStat.where(season:).each_with_object({}) do |player_season_stat, preserved|
        preserved[player_season_stat.player_id] = player_season_stat.attributes.symbolize_keys.slice(
          *PRESERVED_STAT_COLUMNS
        )
      end
    end

    def restore_preserved_stats!(preserved_stats)
      PlayerSeasonStat.where(season:).find_each do |player_season_stat|
        attributes = preserved_stats[player_season_stat.player_id]
        player_season_stat.update!(attributes) if attributes.present?
      end
    end

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
            .order(:played_on, :created_at, :id)
    end

    def finished_matches(match_day)
      match_day.matches
               .includes(home_team: :players, away_team: :players)
               .where.not(finished_at: nil)
               .order(Arel.sql("COALESCE(started_at, created_at) ASC"), :id)
    end

    def process_match(match, elo_map)
      Ratings::ProcessMatchElo.call(match:, season:, force: true)

      match.home_team.players.each do |player|
        elo_map[player.id] = player.reload.elo
      end

      match.away_team.players.each do |player|
        elo_map[player.id] = player.reload.elo
      end
    end

    def persist(elo_map)
      Player.transaction do
        elo_map.each do |player_id, elo|
          Player.where(id: player_id).update_all(elo: elo)
          PlayerSeasonStat.where(player_id:, season:).update_all(elo: elo)
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
