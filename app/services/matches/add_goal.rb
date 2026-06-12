module Matches
  class AddGoal
    def self.call(match:, scorer_team_player_id:, scoring_team_id:, assistant_team_player_id: nil, scored_at: Time.current)
      new(match:, scorer_team_player_id:, scoring_team_id:, assistant_team_player_id:, scored_at:).call
    end

    def initialize(match:, scorer_team_player_id:, scoring_team_id:, assistant_team_player_id:, scored_at:)
      @match = match
      @scorer_team_player_id = scorer_team_player_id
      @scoring_team_id = scoring_team_id
      @assistant_team_player_id = assistant_team_player_id
      @scored_at = scored_at
    end

    def call
      return false unless match.started_at.present?

      Match.transaction do
        goal = match.match_goals.create!(
          scorer_team_player_id:,
          scoring_team_id:,
          assistant_team_player_id:,
          scored_at:,
          home_score_after: next_home_score(goal_scoring_team_id: scoring_team_id),
          away_score_after: next_away_score(goal_scoring_team_id: scoring_team_id)
        )

        match.recalculate_score!

        goal
      end
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :match, :scored_at, :scorer_team_player_id, :scoring_team_id, :assistant_team_player_id

    def next_home_score(goal_scoring_team_id:)
      match.home_score + (goal_scoring_team_id.to_i == match.home_team_id ? 1 : 0)
    end

    def next_away_score(goal_scoring_team_id:)
      match.away_score + (goal_scoring_team_id.to_i == match.away_team_id ? 1 : 0)
    end
  end
end
