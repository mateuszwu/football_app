module PublicStats
  class CacheKey
    TRACKED_MODELS = [
      MatchDay,
      Match,
      MatchGoal,
      MatchDayVote,
      MatchDayVoteToken,
      Player,
      PlayerRatingChange,
      PlayerSeasonStat,
      Team,
      TeamPlayer
    ].freeze

    def self.global
      new.call
    end

    def self.season(season)
      new(season:).call
    end

    def initialize(season: nil)
      @season = season
    end

    def call
      rows = snapshot_rows

      [
        "public-stats",
        season&.id || "all",
        timestamp_part(rows),
        count_part(rows)
      ].join("/")
    end

    private

    attr_reader :season

    def timestamp_part(rows)
      rows
        .filter_map { |row| Time.zone.parse(row.fetch("tracked_timestamp")) if row["tracked_timestamp"].present? }
        .max
        &.utc
        &.to_fs(:number) || "empty"
    end

    def count_part(rows)
      rows.sum { |row| row.fetch("tracked_count").to_i }
    end

    def snapshot_rows
      queries = tracked_scopes.map do |scope|
        table_name = scope.klass.quoted_table_name

        scope
          .unscope(:select, :order, :limit, :offset)
          .select(
            Arel.sql("COUNT(*) AS tracked_count"),
            Arel.sql("MAX(#{table_name}.updated_at) AS tracked_timestamp")
          )
          .to_sql
      end

      ActiveRecord::Base.connection.select_all(queries.join(" UNION ALL ")).to_a
    end

    def tracked_scopes
      @tracked_scopes ||= TRACKED_MODELS.map { |model| scoped_relation_for(model) }
    end

    def scoped_relation_for(model)
      return model.all if season.blank?

      case model.name
      when "MatchDay"
        model.where(season_id: season.id)
      when "Match", "Team", "TeamPlayer", "MatchGoal"
        model.joins(scoped_join_for(model)).where(match_days: { season_id: season.id })
      when "MatchDayVote"
        model.joins(match_day_vote_token: { match_day_player: :match_day }).where(match_days: { season_id: season.id })
      when "MatchDayVoteToken"
        model.joins(match_day_player: :match_day).where(match_days: { season_id: season.id })
      when "PlayerRatingChange", "PlayerSeasonStat"
        model.where(season_id: season.id)
      else
        model.all
      end
    end

    def scoped_join_for(model)
      case model.name
      when "Match"
        :match_day
      when "Team"
        { team_setup: :match_day }
      when "TeamPlayer"
        { team: { team_setup: :match_day } }
      when "MatchGoal"
        { match: :match_day }
      end
    end
  end
end
