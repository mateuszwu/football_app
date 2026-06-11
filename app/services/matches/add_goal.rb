module Matches
  class AddGoal
    def self.call(match:, scorer_id:, scoring_team_id:, scored_at: Time.current)
      new(match:, scorer_id:, scoring_team_id:, scored_at:).call
    end

    def initialize(match:, scorer_id:, scoring_team_id:, scored_at:)
      @match = match
      @scorer_id = scorer_id
      @scoring_team_id = scoring_team_id
      @scored_at = scored_at
    end

    def call
      return false unless match.in_progress?

      Match.transaction do
        goal = match.match_goals.create!(
          scorer_id:,
          scoring_team_id:,
          scored_at:
        )

        match.increment!(score_column)

        goal
      end
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :scored_at, :scorer_id, :scoring_team_id

    def score_column
      scoring_team_id.to_i == match.home_team_id ? :home_score : :away_score
    end
  end
end
