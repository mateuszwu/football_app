module Matches
  class AddGoal
    def self.call(match:, scorer_id:, scoring_team_id:, assistant_id: nil, scored_at: Time.current)
      new(match:, scorer_id:, scoring_team_id:, assistant_id:, scored_at:).call
    end

    def initialize(match:, scorer_id:, scoring_team_id:, assistant_id:, scored_at:)
      @match = match
      @scorer_id = scorer_id
      @scoring_team_id = scoring_team_id
      @assistant_id = assistant_id
      @scored_at = scored_at
    end

    def call
      return false unless match.started_at.present?

      Match.transaction do
        goal = match.match_goals.create!(
          scorer_id:,
          scoring_team_id:,
          assistant_id:,
          scored_at:
        )

        match.recalculate_score!

        goal
      end
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :scored_at, :scorer_id, :scoring_team_id, :assistant_id
  end
end
