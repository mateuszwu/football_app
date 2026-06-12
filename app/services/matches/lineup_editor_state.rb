module Matches
  class LineupEditorState
    def self.call(match:)
      new(match:).call
    end

    def initialize(match:)
      @match = match
    end

    def call
      {
        players: lineup_players,
        teams: lineup_teams
      }
    end

    private

    attr_reader :match

    def lineup_players
      match.match_day.players.order(:name).map do |player|
        {
          id: player.id,
          label: "#{player.name} (#{player.nickname})"
        }
      end
    end

    def lineup_teams
      match.teams.order(:position, :created_at, :id).presence || [ match.home_team, match.away_team ].compact
    end
  end
end
