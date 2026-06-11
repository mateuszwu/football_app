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
        match.update!(finished_at: finished_at)
        match.match_day.update!(status: "finished") if all_match_day_matches_finished?
      end

      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :finished_at

    def all_match_day_matches_finished?
      match.match_day.matches.where(finished_at: nil).none?
    end
  end
end
