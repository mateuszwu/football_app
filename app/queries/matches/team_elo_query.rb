module Matches
  class TeamEloQuery
    def self.call(match:)
      new(match:).call
    end

    def initialize(match:)
      @match = match
    end

    def call
      home_players = team_players_for(match.home_team)
      away_players = team_players_for(match.away_team)
      return empty_result unless historical_snapshot_available?(home_players, :elo_before) && historical_snapshot_available?(away_players, :elo_before)

      before_elo_map = elo_map_for(home_players + away_players, :elo_before)
      after_elo_map = elo_map_for(home_players + away_players, :elo_after) if historical_snapshot_available?(home_players, :elo_after) && historical_snapshot_available?(away_players, :elo_after)

      {
        home: team_elo_summary(home_players, away_players, before_elo_map, after_elo_map),
        away: team_elo_summary(away_players, home_players, before_elo_map, after_elo_map)
      }
    end

    private

    attr_reader :match

    def team_players_for(team)
      team.team_players.includes(:player).to_a
    end

    def historical_snapshot_available?(team_players, attribute)
      team_players.present? && team_players.all? { |team_player| team_player.public_send(attribute).present? }
    end

    def empty_result
      { home: nil, away: nil }
    end

    def elo_map_for(team_players, attribute)
      team_players.to_h { |team_player| [ team_player.player_id, team_player.public_send(attribute) ] }
    end

    def team_elo_summary(team_players, opponent_players, before_elo_map, after_elo_map)
      {
        before: team_elo_for(team_players, opponent_players, before_elo_map),
        after: after_elo_map.present? ? team_elo_for(team_players, opponent_players, after_elo_map) : nil
      }
    end

    def team_elo_for(team_players, opponent_players, elo_map)
      result = Ratings::CalculateTeamElo.call(
        players: team_players.map(&:player),
        opponent_players: opponent_players.map(&:player),
        elo_map:,
        season: match.match_day.season,
        all_roster_players_on_pitch: match.all_roster_players_on_pitch?
      )

      {
        average: result.average_elo.round,
        effective: result.effective_elo.round
      }
    end
  end
end
