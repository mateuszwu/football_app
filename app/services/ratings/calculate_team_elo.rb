module Ratings
  class CalculateTeamElo
    Result = Struct.new(:average_elo, :effective_elo, keyword_init: true)

    def self.call(players:, opponent_players:, elo_map:, season:)
      new(players:, opponent_players:, elo_map:, season:).call
    end

    def initialize(players:, opponent_players:, elo_map:, season:)
      @players = players
      @opponent_players = opponent_players
      @elo_map = elo_map
      @season = season
    end

    def call
      return Result.new(average_elo: 0.0, effective_elo: 0.0) if players.empty?

      average_elo = calculate_average_elo

      Result.new(
        average_elo: average_elo,
        effective_elo: average_elo + player_count_advantage
      )
    end

    private

    attr_reader :players, :opponent_players, :elo_map, :season

    def calculate_average_elo
      players.sum { |player| elo_map[player.id] }.to_f / players.size
    end

    def player_count_advantage
      extra_players_count * season.player_advantage_elo.to_f
    end

    def extra_players_count
      [ players.size - opponent_players.size, 0 ].max
    end
  end
end
