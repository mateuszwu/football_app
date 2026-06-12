module Matches
  class StartMatch
    def self.call(match:, started_at: Time.current)
      new(match:, started_at:).call
    end

    def initialize(match:, started_at:)
      @match = match
      @started_at = started_at
    end

    def call
      return false unless match.not_started?
      return false unless startable_lineup?

      Match.transaction do
        match.update!(started_at: started_at)
        match.match_day.update!(status: "in_progress")
      end

      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :started_at

    def startable_lineup?
      current_match_teams = [ match.home_team, match.away_team ]
      current_match_teams.all? do |team|
        team.team_type == Team::TEAM_TYPE_MATCH && team.players.any?
      end
    end
  end
end
