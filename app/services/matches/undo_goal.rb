module Matches
  class UndoGoal
    def self.call(match:, goal:)
      new(match:, goal:).call
    end

    def initialize(match:, goal:)
      @match = match
      @goal = goal
    end

    def call
      return false unless match.started_at.present?
      return false unless goal.match_id == match.id
      return false if goal.undone?

      Match.transaction do
        goal.update!(undone_at: Time.current)
        match.recalculate_score!
      end

      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :goal
  end
end
