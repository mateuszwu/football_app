module Matches
  class UpdateLineupParams
    def self.call(params:)
      new(params:).call
    end

    def initialize(params:)
      @params = params
    end

    def call
      raw_teams.map do |team|
        team = normalize_team(team)

        {
          id: team[:id],
          name: team[:name],
          captain_id: team[:captain_id],
          player_ids: team[:player_ids] || []
        }
      end
    end

    private

    attr_reader :params

    def raw_teams
      teams_params = params.fetch(:match, {}).fetch(:teams_data, [])

      if teams_params.is_a?(Hash)
        teams_params.values
      else
        Array(teams_params)
      end
    end

    def normalize_team(team)
      return team.symbolize_keys if team.is_a?(Hash)
      return team.to_unsafe_h.symbolize_keys if team.respond_to?(:to_unsafe_h)

      team.to_h.symbolize_keys
    end
  end
end
