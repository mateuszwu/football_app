module Stats
  class SeasonInsightsQuery
    TABS = %w[tempo first_goal comebacks score_states records clutch].freeze
    DEFICIT_THRESHOLDS = [ 1, 2, 3, 4 ].freeze

    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      {
        season:,
        top_cards:,
        tempo:,
        first_goal:,
        closing_goals: closing_goal_rows,
        comebacks:,
        score_states:,
        records:,
        clutch_players:,
        sidebar:,
        chart_data:
      }
    end

    private

    attr_reader :season

    def timelines
      @timelines ||= matches.map { |match| Stats::MatchTimelineQuery.call(match:) }
    end

    def matches
      @matches ||= Match
        .joins(:match_day)
        .where(status: Match::STATUS_FINISHED, match_days: { season_id: season.id })
        .includes(
          :match_day,
          :home_team,
          :away_team,
          active_match_goals: [
            :scoring_team,
            { scorer_team_player: :player },
            { assistant_team_player: :player }
          ]
        )
        .order("match_days.played_on ASC", :id)
    end

    def completed_timelines
      @completed_timelines ||= timelines.select { |timeline| timeline.summary.fetch(:completed_to_5) }
    end

    def timed_events
      @timed_events ||= timelines.flat_map(&:events).select { |event| event.fetch(:occurred_at_seconds).present? }
    end

    def first_goal_events
      @first_goal_events ||= completed_timelines.filter_map { |timeline| timeline.summary.fetch(:first_goal_event) }
    end

    def closing_goal_events
      @closing_goal_events ||= completed_timelines.filter_map { |timeline| timeline.summary.fetch(:closing_goal_event) }
    end

    def top_cards
      {
        fastest_goal: event_card(timed_events.min_by { |event| event.fetch(:occurred_at_seconds) }),
        latest_first_goal: event_card(first_goal_events.select { |event| event.fetch(:occurred_at_seconds).present? }.max_by { |event| event.fetch(:occurred_at_seconds) }),
        shortest_match: match_card(completed_timelines.select { |timeline| timeline.summary.fetch(:duration_seconds).present? }.min_by { |timeline| timeline.summary.fetch(:duration_seconds) }),
        longest_match: match_card(completed_timelines.select { |timeline| timeline.summary.fetch(:duration_seconds).present? }.max_by { |timeline| timeline.summary.fetch(:duration_seconds) })
      }
    end

    def tempo
      durations = completed_timelines.filter_map { |timeline| timeline.summary.fetch(:duration_seconds) }
      first_goal_times = first_goal_events.filter_map { |event| event.fetch(:occurred_at_seconds) }
      goal_gaps = completed_timelines.flat_map { |timeline| goal_gaps_for(timeline) }

      {
        average_match_duration: average(durations),
        average_time_to_first_goal: average(first_goal_times),
        average_time_between_goals: average(goal_gaps),
        records: tempo_records
      }
    end

    def tempo_records
      [
        record_row("fastest_goal", event_card(timed_events.min_by { |event| event.fetch(:occurred_at_seconds) })),
        record_row("latest_first_goal", event_card(first_goal_events.select { |event| event.fetch(:occurred_at_seconds).present? }.max_by { |event| event.fetch(:occurred_at_seconds) })),
        record_row("shortest_match", match_card(completed_timelines.select { |timeline| timeline.summary.fetch(:duration_seconds).present? }.min_by { |timeline| timeline.summary.fetch(:duration_seconds) })),
        record_row("longest_match", match_card(completed_timelines.select { |timeline| timeline.summary.fetch(:duration_seconds).present? }.max_by { |timeline| timeline.summary.fetch(:duration_seconds) })),
        record_row("longest_goal_gap", longest_goal_gap_card)
      ]
    end

    def first_goal
      valid_events = first_goal_events.select { |event| winner_for(event).present? }
      wins_after_first = valid_events.count { |event| winner_for(event) == event.fetch(:scoring_team) }
      grouped = first_goal_events.group_by { |event| event.fetch(:scorer) }

      {
        matches_count: valid_events.count,
        wins_after_first_goal: wins_after_first,
        first_goal_win_rate: percentage(wins_after_first, valid_events.count),
        no_win_after_first_goal_rate: percentage(valid_events.count - wins_after_first, valid_events.count),
        player_rows: grouped.map { |player, events| first_goal_player_row(player, events) }.sort_by { |row| [ -row.fetch(:first_goals), row.fetch(:player).name ] }
      }
    end

    def comebacks
      comeback_wins = completed_timelines.select { |timeline| timeline.summary.fetch(:biggest_deficit_overcome_by_winner).positive? }
      first_goal_valid = first_goal_events.select { |event| winner_for(event).present? }
      first_goal_losses = first_goal_valid.count { |event| winner_for(event) != event.fetch(:scoring_team) }
      four_zero_states = state_occurrences.select { |state| state.fetch(:lead) == 4 && state.fetch(:trail) == 0 }
      four_zero_wins = four_zero_states.count { |state| state.fetch(:leader_won) }

      {
        biggest_comeback: comeback_card(completed_timelines.max_by { |timeline| timeline.summary.fetch(:biggest_deficit_overcome_by_winner) }),
        biggest_wasted_lead: wasted_lead_card(completed_timelines.max_by { |timeline| timeline.summary.fetch(:biggest_wasted_lead_by_loser) }),
        wins_after_conceding_first_goal_rate: percentage(first_goal_losses, first_goal_valid.count),
        lead_four_zero_hold_rate: percentage(four_zero_wins, four_zero_states.count),
        comeback_matches_count: comeback_wins.count,
        threshold_rows: DEFICIT_THRESHOLDS.map { |threshold| comeback_threshold_row(threshold) }
      }
    end

    def score_states
      grouped = state_occurrences.group_by { |state| state.fetch(:state) }
      rows = grouped.map do |state, occurrences|
        leader_wins = occurrences.count { |occurrence| occurrence.fetch(:leader_won) }
        {
          state:,
          occurrences: occurrences.count,
          leader_wins:,
          hold_rate: percentage(leader_wins, occurrences.count),
          comeback_count: occurrences.count - leader_wins,
          small_sample: occurrences.count < 3
        }
      end.sort_by { |row| [ -row.fetch(:occurrences), row.fetch(:state) ] }

      {
        rows:,
        most_common: rows.first
      }
    end

    def records
      {
        rows: [
          record_row("most_goals_match", most_goals_by_player_in_match_card),
          record_row("closest_match", match_card(completed_timelines.select { |timeline| final_goal_difference(timeline) == 1 }.max_by { |timeline| [ timeline.summary.fetch(:duration_seconds).to_i, timeline.summary.fetch(:equalizers_count) ] })),
          record_row("biggest_domination", biggest_domination_card),
          record_row("most_lead_changes", match_card(completed_timelines.max_by { |timeline| timeline.summary.fetch(:lead_changes_count) }, value: ->(timeline) { timeline.summary.fetch(:lead_changes_count).to_s })),
          record_row("most_equalizers", match_card(completed_timelines.max_by { |timeline| timeline.summary.fetch(:equalizers_count) }, value: ->(timeline) { timeline.summary.fetch(:equalizers_count).to_s })),
          record_row("longest_goal_gap", longest_goal_gap_card),
          record_row("longest_scoring_run", scoring_run_card)
        ]
      }
    end

    def clutch_players
      rows = Hash.new { |hash, player| hash[player] = new_clutch_row(player) }
      comeback_match_ids = completed_timelines.select { |timeline| timeline.summary.fetch(:biggest_deficit_overcome_by_winner) >= 2 }.map { |timeline| timeline.match.id }

      completed_timelines.each do |timeline|
        timeline.events.each do |event|
          player = event.fetch(:scorer)
          row = rows[player]
          row[:opening_goals] += 1 if event.fetch(:is_first_goal)
          row[:closing_goals] += 1 if event.fetch(:is_closing_goal)
          row[:go_ahead_goals] += 1 if event.fetch(:is_go_ahead_goal)
          row[:equalizer_goals] += 1 if event.fetch(:is_equalizer)
          row[:goals_when_tied] += 1 if tied?(event.fetch(:score_before))
          row[:comeback_contribution] += 1 if comeback_match_ids.include?(timeline.match.id) && event.fetch(:was_team_trailing_before_goal)

          assister = event.fetch(:assister)
          rows[assister][:comeback_contribution] += 1 if assister.present? && comeback_match_ids.include?(timeline.match.id) && event.fetch(:was_team_trailing_before_goal)
        end
      end

      rows.values.sort_by { |row| [ -row.fetch(:closing_goals), -row.fetch(:go_ahead_goals), -row.fetch(:opening_goals), row.fetch(:player).name ] }
    end

    def sidebar
      {
        most_interesting_match: interesting_match_card,
        biggest_comeback: comebacks.fetch(:biggest_comeback),
        quick: {
          wins_after_conceding_first: comebacks.fetch(:wins_after_conceding_first_goal_rate),
          lead_four_zero_hold: comebacks.fetch(:lead_four_zero_hold_rate),
          comeback_matches_count: comebacks.fetch(:comeback_matches_count)
        }
      }
    end

    def chart_data
      {
        match_durations: {
          labels: completed_timelines.map { |timeline| match_label_for(timeline.match) },
          datasets: [
            {
              label: I18n.t("statistics.index.tempo.minutes"),
              data: completed_timelines.map { |timeline| (timeline.summary.fetch(:duration_seconds).to_f / 60).round(2) },
              backgroundColor: "rgba(124, 255, 58, 0.72)",
              borderColor: "#7CFF3A"
            }
          ]
        },
        first_goal_outcome: {
          labels: [ I18n.t("statistics.index.first_goal.win_after_first_goal"), I18n.t("statistics.index.first_goal.lost_after_first_goal") ],
          datasets: [
            {
              data: [ first_goal.fetch(:wins_after_first_goal), first_goal.fetch(:matches_count) - first_goal.fetch(:wins_after_first_goal) ],
              backgroundColor: [ "#22C55E", "#EF4444" ],
              borderColor: "#0B1728"
            }
          ]
        }
      }
    end

    def state_occurrences
      @state_occurrences ||= completed_timelines.flat_map do |timeline|
        winner = timeline.summary.fetch(:winner_team)
        timeline.events.filter_map do |event|
          score = event.fetch(:score_after)
          next if event.fetch(:is_closing_goal)
          next if tied?(score)

          leader_key = score.fetch(:team_a) > score.fetch(:team_b) ? :team_a : :team_b
          trail_key = leader_key == :team_a ? :team_b : :team_a
          lead = score.fetch(leader_key)
          trail = score.fetch(trail_key)

          {
            state: "#{lead}:#{trail}",
            lead:,
            trail:,
            leader_team: leader_key == :team_a ? timeline.match.home_team : timeline.match.away_team,
            leader_won: winner == (leader_key == :team_a ? timeline.match.home_team : timeline.match.away_team),
            timeline:
          }
        end
      end
    end

    def comeback_threshold_row(threshold)
      occurrences = completed_timelines.flat_map do |timeline|
        [ :team_a, :team_b ].filter_map do |team_key|
          max_deficit = timeline.events
            .select { |event| event.fetch(:scoring_team_key) == team_key }
            .map { |event| event.fetch(:deficit_before_goal) }
            .max.to_i
          next if max_deficit < threshold

          winner_key = timeline.summary.fetch(:winner_team) == timeline.match.home_team ? :team_a : :team_b
          {
            timeline:,
            won: winner_key == team_key,
            max_deficit:
          }
        end
      end
      wins = occurrences.count { |occurrence| occurrence.fetch(:won) }
      best = occurrences.select { |occurrence| occurrence.fetch(:won) }.max_by { |occurrence| occurrence.fetch(:max_deficit) }

      {
        deficit: "0:#{threshold}",
        situations: occurrences.count,
        comeback_wins: wins,
        comeback_rate: percentage(wins, occurrences.count),
        best_example: best ? match_card(best.fetch(:timeline)) : nil
      }
    end

    def first_goal_player_row(player, events)
      wins = events.count { |event| winner_for(event) == event.fetch(:scoring_team) }

      {
        player:,
        first_goals: events.count,
        matches: events.count,
        first_goal_rate: percentage(events.count, completed_timelines.count),
        win_rate_after_first_goal: percentage(wins, events.count)
      }
    end

    def closing_goal_rows
      closing_goal_events.group_by { |event| event.fetch(:scorer) }
        .map { |player, events| { player:, closing_goals: events.count } }
        .sort_by { |row| [ -row.fetch(:closing_goals), row.fetch(:player).name ] }
    end

    def new_clutch_row(player)
      {
        player:,
        opening_goals: 0,
        closing_goals: 0,
        go_ahead_goals: 0,
        equalizer_goals: 0,
        goals_when_tied: 0,
        comeback_contribution: 0
      }
    end

    def event_card(event)
      return nil if event.blank?

      {
        value: format_seconds(event.fetch(:occurred_at_seconds)),
        subject: event.fetch(:scorer).name,
        detail: match_detail_for(event.fetch(:event).match),
        match: event.fetch(:event).match,
        path: Rails.application.routes.url_helpers.match_path(event.fetch(:event).match),
        seconds: event.fetch(:occurred_at_seconds)
      }
    end

    def match_card(timeline, value: nil)
      return nil if timeline.blank?

      raw_value = value.respond_to?(:call) ? value.call(timeline) : nil
      {
        value: raw_value || format_seconds(timeline.summary.fetch(:duration_seconds)) || final_score_for(timeline),
        subject: match_label_for(timeline.match),
        detail: final_score_for(timeline),
        match: timeline.match,
        path: Rails.application.routes.url_helpers.match_path(timeline.match),
        seconds: timeline.summary.fetch(:duration_seconds)
      }
    end

    def comeback_card(timeline)
      return nil if timeline.blank? || timeline.summary.fetch(:biggest_deficit_overcome_by_winner).to_i.zero?

      match_card(timeline, value: ->(candidate) { "0:#{candidate.summary.fetch(:biggest_deficit_overcome_by_winner)} → #{final_score_for(candidate)}" })
    end

    def wasted_lead_card(timeline)
      return nil if timeline.blank? || timeline.summary.fetch(:biggest_wasted_lead_by_loser).to_i.zero?

      match_card(timeline, value: ->(candidate) { "#{candidate.summary.fetch(:biggest_wasted_lead_by_loser)}:0 → #{final_score_for(candidate)}" })
    end

    def longest_goal_gap_card
      timeline = completed_timelines.select { |candidate| candidate.summary.fetch(:longest_goalless_stretch_seconds).present? }
        .max_by { |candidate| candidate.summary.fetch(:longest_goalless_stretch_seconds) }
      return nil if timeline.blank?

      match_card(timeline, value: ->(candidate) { format_seconds(candidate.summary.fetch(:longest_goalless_stretch_seconds)) })
    end

    def scoring_run_card
      timeline = completed_timelines.max_by { |candidate| candidate.summary.dig(:longest_scoring_run, :goals_count).to_i }
      return nil if timeline.blank?

      match_card(timeline, value: ->(candidate) { "#{candidate.summary.dig(:longest_scoring_run, :goals_count)} goli" })
    end

    def most_goals_by_player_in_match_card
      row = completed_timelines.flat_map do |timeline|
        timeline.events
          .reject { |event| event.fetch(:event).own_goal? }
          .group_by { |event| event.fetch(:scorer) }
          .map do |player, events|
            {
              player:,
              match: timeline.match,
              goals_count: events.count
            }
          end
      end.max_by { |candidate| [ candidate.fetch(:goals_count), -candidate.fetch(:match).id ] }
      return nil if row.blank?

      {
        value: I18n.t("statistics.index.records.goals_count", count: row.fetch(:goals_count)),
        subject: row.fetch(:player).name,
        detail: match_label_for(row.fetch(:match)),
        match: row.fetch(:match),
        path: Rails.application.routes.url_helpers.match_path(row.fetch(:match))
      }
    end

    def biggest_domination_card
      timeline = completed_timelines.max_by do |candidate|
        [
          final_goal_difference(candidate),
          -winner_goals_against(candidate),
          -(candidate.summary.fetch(:duration_seconds).to_i),
          -candidate.match.id
        ]
      end
      return nil if timeline.blank?

      {
        value: "+#{final_goal_difference(timeline)} / #{final_score_for(timeline)}",
        subject: match_label_for(timeline.match),
        detail: match_detail_for(timeline.match),
        match: timeline.match,
        path: Rails.application.routes.url_helpers.match_path(timeline.match),
        seconds: timeline.summary.fetch(:duration_seconds)
      }
    end

    def interesting_match_card
      timeline = completed_timelines.max_by do |candidate|
        candidate.summary.fetch(:biggest_deficit_overcome_by_winner).to_i * 5 +
          candidate.summary.fetch(:final_score).values.sum +
          candidate.summary.fetch(:lead_changes_count).to_i * 2 +
          candidate.summary.fetch(:equalizers_count).to_i +
          (candidate.summary.fetch(:duration_seconds).to_i / 300)
      end

      match_card(timeline)
    end

    def record_row(key, card)
      {
        key:,
        subject: card&.fetch(:subject),
        detail: card&.fetch(:detail),
        value: card&.fetch(:value),
        match: card&.fetch(:match),
        path: card&.fetch(:path)
      }
    end

    def goal_gaps_for(timeline)
      previous_time = 0
      timeline.events.filter_map do |event|
        current_time = event.fetch(:occurred_at_seconds)
        next if current_time.blank?

        gap = current_time - previous_time
        previous_time = current_time
        gap
      end
    end

    def winner_for(event)
      timeline = completed_timelines.find { |candidate| candidate.match.id == event.fetch(:event).match_id }
      timeline&.summary&.fetch(:winner_team)
    end

    def final_goal_difference(timeline)
      score = timeline.summary.fetch(:final_score)
      (score.fetch(:team_a) - score.fetch(:team_b)).abs
    end

    def winner_goals_against(timeline)
      score = timeline.summary.fetch(:final_score)

      [ score.fetch(:team_a), score.fetch(:team_b) ].min
    end

    def final_score_for(timeline)
      score = timeline.summary.fetch(:final_score)
      "#{score.fetch(:team_a)}:#{score.fetch(:team_b)}"
    end

    def match_label_for(match)
      "#{match.match_day.played_on} · ##{match.id}"
    end

    def match_detail_for(match)
      "#{match.home_team.name} #{match.home_score}:#{match.away_score} #{match.away_team.name}"
    end

    def average(values)
      compact_values = values.compact
      return nil if compact_values.empty?

      (compact_values.sum.to_f / compact_values.count).round
    end

    def percentage(value, total)
      return 0 if total.to_i.zero?

      ((value.to_f / total) * 100).round
    end

    def tied?(score)
      score.fetch(:team_a) == score.fetch(:team_b)
    end

    def format_seconds(seconds)
      return nil if seconds.blank?

      minutes = seconds / 60
      remaining_seconds = seconds % 60
      format("%<minutes>02d:%<seconds>02d", minutes:, seconds: remaining_seconds)
    end
  end
end
