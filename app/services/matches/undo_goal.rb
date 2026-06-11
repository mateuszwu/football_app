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
      return false unless match.in_progress?
      return false unless goal.match_id == match.id

      Match.transaction do
        match.decrement!(score_column)
        goal.destroy!
      end

      true
    rescue ActiveRecord::RecordNotDestroyed
      false
    end

    private

    attr_reader :match, :goal

    def score_column
      goal.scoring_team_id == match.home_team_id ? :home_score : :away_score
    end
  end
end
