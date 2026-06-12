module Ratings
  class EffectiveTeamElo
    PLAYER_COUNT_ADVANTAGE = 40

    def self.call(players:, opponent_players:, elo_map:)
      new(players:, opponent_players:, elo_map:).call
    end

    def initialize(players:, opponent_players:, elo_map:)
      @players = players
      @opponent_players = opponent_players
      @elo_map = elo_map
    end

    def call
      return 0.0 if players.empty?

      average_elo + player_count_advantage
    end

    private

    attr_reader :players, :opponent_players, :elo_map

    def average_elo
      players.sum { |player| elo_map[player.id] }.to_f / players.size
    end

    def player_count_advantage
      (players.size - opponent_players.size) * PLAYER_COUNT_ADVANTAGE
    end
  end
end
