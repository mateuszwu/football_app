module Ratings
  class RecalculateGlobalElo
    def self.call
      new.call
    end

    def call
      reset_global_elo!

      seasons_in_order.each do |season|
        Ratings::RecalculateSeasonElo.call(season:)
      end
    end

    private

    def reset_global_elo!
      Player.update_all(elo: 1000)
    end

    def seasons_in_order
      Season.order(:starts_on, :created_at, :id)
    end
  end
end
