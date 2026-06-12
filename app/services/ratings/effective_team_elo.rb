module Ratings
  class EffectiveTeamElo
    def self.call(players:, opponent_players:, elo_map:, season:)
      CalculateTeamElo.call(
        players: players,
        opponent_players: opponent_players,
        elo_map: elo_map,
        season: season
      ).effective_elo
    end
  end
end
