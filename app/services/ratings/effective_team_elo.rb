module Ratings
  class EffectiveTeamElo
    def self.call(players:, elo_map:)
      new(players:, elo_map:).call
    end

    def initialize(players:, elo_map:)
      @players = players
      @elo_map = elo_map
    end

    def call
      return 0.0 if players.empty?

      players.sum { |player| elo_map[player.id] }.to_f / players.size
    end

    private

    attr_reader :players, :elo_map
  end
end
