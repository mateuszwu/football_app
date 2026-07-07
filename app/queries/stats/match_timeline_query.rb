module Stats
  class MatchTimelineQuery
    FINISHING_SCORE = 5

    Result = Struct.new(:match, :events, :summary, keyword_init: true)

    def self.call(match:)
      new(match:).call
    end

    def initialize(match:)
      @match = match
    end

    def call
      events = build_events

      Result.new(
        match:,
        events:,
        summary: summary_for(events)
      )
    end

    private

    attr_reader :match

    def build_events
      score = { team_a: 0, team_b: 0 }
      previous_leader = nil

      ordered_goals.each_with_index.map do |goal, index|
        team_key = team_key_for(goal.scoring_team_id)
        score_before = score.dup
        score[team_key] += 1
        score_after = score.dup
        leader_before = leader_for(score_before)
        leader_after = leader_for(score_after)
        opponent_key = opponent_key_for(team_key)
        deficit_before_goal = [ score_before.fetch(opponent_key) - score_before.fetch(team_key), 0 ].max

        event = {
          event: goal,
          scorer: goal.scorer,
          assister: goal.assistant,
          scoring_team: goal.scoring_team,
          occurred_at_seconds: occurred_at_seconds_for(goal),
          sequence_number: goal.id,
          score_before:,
          score_after:,
          is_first_goal: index.zero?,
          is_closing_goal: score_after.fetch(team_key) == FINISHING_SCORE,
          is_equalizer: deficit_before_goal == 1 && score_after.fetch(:team_a) == score_after.fetch(:team_b),
          is_go_ahead_goal: leader_before.nil? && leader_after == team_key,
          was_team_trailing_before_goal: deficit_before_goal.positive?,
          deficit_before_goal:,
          goal_number_for_team: score_after.fetch(team_key),
          match_goal_number: index + 1,
          scoring_team_key: team_key,
          previous_leader:,
          leader_after:
        }

        previous_leader = leader_after if leader_after.present?
        event
      end
    end

    def ordered_goals
      @ordered_goals ||= match.active_match_goals
        .includes(:scoring_team, scorer_team_player: :player, assistant_team_player: :player)
        .sort_by { |goal| [ occurred_at_seconds_for(goal) || Float::INFINITY, goal.scored_at || Time.zone.at(0), goal.id ] }
    end

    def summary_for(events)
      final_score = events.last&.fetch(:score_after) || { team_a: 0, team_b: 0 }
      winner_key = leader_for(final_score)
      loser_key = winner_key ? opponent_key_for(winner_key) : nil
      first_goal_event = events.first
      closing_goal_event = events.find { |event| event.fetch(:is_closing_goal) }
      completed_to_5 = completed_to_5?(final_score, closing_goal_event)

      {
        final_score:,
        winner_team: team_for_key(winner_key),
        loser_team: team_for_key(loser_key),
        completed_to_5:,
        duration_seconds: completed_to_5 ? closing_goal_event&.fetch(:occurred_at_seconds) : nil,
        first_goal_event:,
        closing_goal_event:,
        max_lead_by_winner: max_lead_for(events, winner_key),
        max_lead_by_loser: max_lead_for(events, loser_key),
        biggest_deficit_overcome_by_winner: biggest_deficit_for(events, winner_key),
        biggest_wasted_lead_by_loser: max_lead_for(events, loser_key),
        lead_changes_count: lead_changes_count_for(events),
        equalizers_count: events.count { |event| event.fetch(:is_equalizer) },
        longest_goalless_stretch_seconds: longest_goalless_stretch_for(events),
        longest_scoring_run: longest_scoring_run_for(events)
      }
    end

    def completed_to_5?(final_score, closing_goal_event)
      return false if closing_goal_event.blank?
      return false unless [ final_score.fetch(:team_a), final_score.fetch(:team_b) ].max == FINISHING_SCORE

      final_score.fetch(:team_a) == match.home_score.to_i && final_score.fetch(:team_b) == match.away_score.to_i
    end

    def occurred_at_seconds_for(goal)
      return nil if match.started_at.blank? || goal.scored_at.blank?

      [ goal.scored_at.to_i - match.started_at.to_i, 0 ].max
    end

    def team_key_for(team_id)
      team_id == match.home_team_id ? :team_a : :team_b
    end

    def opponent_key_for(team_key)
      team_key == :team_a ? :team_b : :team_a
    end

    def team_for_key(team_key)
      return nil if team_key.blank?

      team_key == :team_a ? match.home_team : match.away_team
    end

    def leader_for(score)
      return :team_a if score.fetch(:team_a) > score.fetch(:team_b)
      return :team_b if score.fetch(:team_b) > score.fetch(:team_a)

      nil
    end

    def max_lead_for(events, team_key)
      return 0 if team_key.blank?

      opponent_key = opponent_key_for(team_key)
      events.map { |event| event.fetch(:score_after).fetch(team_key) - event.fetch(:score_after).fetch(opponent_key) }.max.to_i
    end

    def biggest_deficit_for(events, team_key)
      return 0 if team_key.blank?

      events.select { |event| event.fetch(:scoring_team_key) == team_key }.map { |event| event.fetch(:deficit_before_goal) }.max.to_i
    end

    def lead_changes_count_for(events)
      previous_leader = nil
      changes = 0

      events.each do |event|
        leader = event.fetch(:leader_after)
        next if leader.blank?

        changes += 1 if previous_leader.present? && previous_leader != leader
        previous_leader = leader
      end

      changes
    end

    def longest_goalless_stretch_for(events)
      timed_events = events.select { |event| event.fetch(:occurred_at_seconds).present? }
      return nil if timed_events.empty?

      previous_time = 0
      timed_events.map do |event|
        stretch = event.fetch(:occurred_at_seconds) - previous_time
        previous_time = event.fetch(:occurred_at_seconds)
        stretch
      end.max
    end

    def longest_scoring_run_for(events)
      best_team_key = nil
      best_count = 0
      current_team_key = nil
      current_count = 0

      events.each do |event|
        team_key = event.fetch(:scoring_team_key)
        if team_key == current_team_key
          current_count += 1
        else
          current_team_key = team_key
          current_count = 1
        end

        next unless current_count > best_count

        best_team_key = team_key
        best_count = current_count
      end

      {
        team: team_for_key(best_team_key),
        goals_count: best_count
      }
    end
  end
end
