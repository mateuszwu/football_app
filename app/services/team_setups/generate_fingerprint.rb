module TeamSetups
  class GenerateFingerprint
    def self.call(team_setup:)
      new(team_setup:).call
    end

    def initialize(team_setup:)
      @team_setup = team_setup
    end

    def call
      Digest::SHA256.hexdigest(fingerprint_source)
    end

    private

    attr_reader :team_setup

    def fingerprint_source
      ordered_teams.map do |team|
        [ team.team_type, team.name, sorted_player_ids_for(team).join(",") ].join(":")
      end.join("|")
    end

    def ordered_teams
      team_setup.teams.includes(:team_players).sort_by { |team| [ team.team_type, team.name, team.id ] }
    end

    def sorted_player_ids_for(team)
      team.team_players.map(&:player_id).sort
    end
  end
end
