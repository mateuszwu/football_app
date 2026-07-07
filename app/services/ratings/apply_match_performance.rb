module Ratings
  class ApplyMatchPerformance
    def self.call(match:, season: match.match_day.season)
      new(match:, season:).call
    end

    def initialize(match:, season:)
      @match = match
      @season = season
    end

    def call
      return false unless processable_match?

      Match.transaction do
        active_goals.each do |goal|
          apply_goal(goal)
        end

        match.update!(performance_processed_at: Time.current)
      end

      true
    end

    private

    attr_reader :match, :season

    def processable_match?
      return false if match.performance_processed_at.present?
      return false unless match.finished?

      true
    end

    def active_goals
      @active_goals ||= match.active_match_goals.includes(scorer_team_player: :player, assistant_team_player: :player)
    end

    def apply_goal(goal)
      unless goal.own_goal?
        apply_player_points(player: goal.scorer, goal_delta: 1, assist_delta: 0, performance_delta: season.goal_points)
        Ratings::RecordPlayerRatingChange.call(
          player: goal.scorer,
          season:,
          match_day: match.match_day,
          match:,
          rating_scope: PlayerRatingChange::RATING_SCOPE_SEASON,
          source_type: PlayerRatingChange::SOURCE_TYPE_GOAL,
          reason: "goal_performance",
          performance_delta: season.goal_points
        )
      end

      return unless goal.assistant.present?

      apply_player_points(player: goal.assistant, goal_delta: 0, assist_delta: 1, performance_delta: season.assist_points)
      Ratings::RecordPlayerRatingChange.call(
        player: goal.assistant,
        season:,
        match_day: match.match_day,
        match:,
        rating_scope: PlayerRatingChange::RATING_SCOPE_SEASON,
        source_type: PlayerRatingChange::SOURCE_TYPE_ASSIST,
        reason: "assist_performance",
        performance_delta: season.assist_points
      )
    end

    def apply_player_points(player:, goal_delta:, assist_delta:, performance_delta:)
      player_season_stat = Ratings::InitializePlayerSeasonStat.call(player:, season:)

      player_season_stat.update!(
        goals: player_season_stat.goals + goal_delta,
        assists: player_season_stat.assists + assist_delta,
        performance_score: player_season_stat.performance_score + performance_delta
      )

      player.update!(global_performance_score: player.global_performance_score + performance_delta)
    end
  end
end
