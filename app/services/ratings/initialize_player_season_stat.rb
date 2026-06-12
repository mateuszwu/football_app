module Ratings
  class InitializePlayerSeasonStat
    def self.call(player:, season:)
      new(player:, season:).call
    end

    def initialize(player:, season:)
      @player = player
      @season = season
    end

    def call
      PlayerSeasonStat.find_or_initialize_by(player:, season:).tap do |player_season_stat|
        next unless player_season_stat.new_record?

        player_season_stat.elo = initial_elo
        player_season_stat.save!
      end
    end

    private

    attr_reader :player, :season

    def initial_elo
      base_elo = season.initial_elo
      global_elo = player.elo || base_elo

      (base_elo + ((global_elo - base_elo) * season.season_elo_carryover_factor)).round
    end
  end
end
