module Players
  class BestTeammatesQuery
    def self.call(player:)
      new(player:).call
    end

    def initialize(player:)
      @player = player
    end

    def call
      teammates = Players::SharedMatchDaysQuery.call(player: player).to_a
      return [] if teammates.empty?

      best_shared_match_days_count = teammates.first.shared_match_days_count.to_i

      teammates.select { |teammate| teammate.shared_match_days_count.to_i == best_shared_match_days_count }
    end

    private

    attr_reader :player
  end
end
