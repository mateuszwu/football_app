module Players
  class SharedMatchDaysQuery
    def self.call(player:)
      new(player:).call
    end

    def initialize(player:)
      @player = player
    end

    def call
      Player
        .joins(:match_day_players)
        .where(match_day_players: { match_day_id: player.match_days.select(:id) })
        .where.not(id: player.id)
        .select("players.*, COUNT(DISTINCT match_day_players.match_day_id) AS shared_match_days_count")
        .group("players.id")
        .order(Arel.sql("shared_match_days_count DESC"), :name)
    end

    private

    attr_reader :player
  end
end
