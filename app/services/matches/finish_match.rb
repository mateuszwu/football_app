module Matches
  class FinishMatch
    def self.call(match:, finished_at: Time.current)
      new(match:, finished_at:).call
    end

    def initialize(match:, finished_at:)
      @match = match
      @finished_at = finished_at
    end

    def call
      return false unless match.in_progress?

      Match.transaction do
        update_team_results!
        match.update!(finished_at: finished_at)
        match.match_day.update!(status: "finished") if all_match_day_matches_finished?
      end

      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :finished_at

    def update_team_results!
      home_team = match.home_team
      away_team = match.away_team

      if match.draw?
        home_team.update!(result: Team::RESULT_DRAW)
        away_team.update!(result: Team::RESULT_DRAW)
        return
      end

      if match.home_win?
        home_team.update!(result: Team::RESULT_WIN)
        away_team.update!(result: Team::RESULT_LOSS)
      else
        home_team.update!(result: Team::RESULT_LOSS)
        away_team.update!(result: Team::RESULT_WIN)
      end
    end

    def all_match_day_matches_finished?
      match.match_day.matches.where(finished_at: nil).none?
    end
  end
end
