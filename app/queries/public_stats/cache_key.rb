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
      [
        "public-stats",
        season&.id || "all",
        timestamp_part,
        count_part
      ].join("/")
    end

    private

    attr_reader :season

    def timestamp_part
      timestamps.compact.max&.utc&.to_fs(:number) || "empty"
    end

    def count_part
      tracked_scopes.sum(&:count)
    end

    def timestamps
      tracked_scopes.map { |scope| scope.maximum(:updated_at) }
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
