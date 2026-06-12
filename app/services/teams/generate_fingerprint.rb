module Teams
  class GenerateFingerprint
    def self.call(team:)
      new(team:).call
    end

    def initialize(team:)
      @team = team
    end

    def call
      sorted_player_ids.join("-")
    end

    private

    attr_reader :team

    def sorted_player_ids
      team.team_players.pluck(:player_id).sort
    end
  end
end
