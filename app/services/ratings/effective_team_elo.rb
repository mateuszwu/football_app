module Ratings
  class EffectiveTeamElo
    def self.call(players:, opponent_players:, elo_map:, season:, all_roster_players_on_pitch: false)
      CalculateTeamElo.call(players:, opponent_players:, elo_map:, season:, all_roster_players_on_pitch:).effective_elo
    end
  end
end
