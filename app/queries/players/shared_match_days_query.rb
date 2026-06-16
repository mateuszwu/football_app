module Players
  class SharedMatchDaysQuery
    def self.call(player:, season: nil)
      new(player:, season:).call
    end

    def initialize(player:, season:)
      @player = player
      @season = season
    end

    def call
      Player
        .joins(match_day_players: :match_day)
        .where(match_day_players: { match_day_id: scoped_match_day_ids })
        .where.not(id: player.id)
        .select("players.*, COUNT(DISTINCT match_day_players.match_day_id) AS shared_match_days_count")
        .group("players.id")
        .order(Arel.sql("shared_match_days_count DESC"), :name)
    end

    private

    attr_reader :player, :season

    def scoped_match_day_ids
      scope = player.match_days
      scope = scope.where(season:) if season.present?
      scope.select(:id)
    end
  end
end
