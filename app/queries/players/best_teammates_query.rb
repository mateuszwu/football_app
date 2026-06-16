module Players
  class BestTeammatesQuery
    def self.call(player:, season: nil)
      new(player:, season:).call
    end

    def initialize(player:, season:)
      @player = player
      @season = season
    end

    def call
      teammates = Players::SharedMatchDaysQuery.call(player:, season:).to_a
      return [] if teammates.empty?

      best_shared_match_days_count = teammates.first.shared_match_days_count.to_i

      teammates.select { |teammate| teammate.shared_match_days_count.to_i == best_shared_match_days_count }
    end

    private

    attr_reader :player, :season
  end
end
