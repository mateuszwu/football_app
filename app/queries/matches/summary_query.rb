module Matches
  class SummaryQuery
    Result = Struct.new(
      :match,
      :season,
      :match_day,
      :teams,
      :score,
      :time,
      :status,
      :timeline,
      :score_progression,
      :summary_cards,
      :team_rosters,
      :match_summary,
      :awards,
      keyword_init: true
    )

    def self.call(match:)
      new(match:).call
    end

    def initialize(match:)
      @match = match
      @timeline_result = Stats::MatchTimelineQuery.call(match:)
    end

    def call
      Result.new(
        match:,
        season: match.match_day.season,
        match_day: match.match_day,
        teams: { home: match.home_team, away: match.away_team },
        score: score,
        time: time,
        status: status,
        timeline: timeline,
        score_progression: score_progression,
        summary_cards: summary_cards,
        team_rosters: team_rosters,
        match_summary: match_summary,
        awards: awards
      )
    end

    private

    attr_reader :match, :timeline_result

    def score
      {
        home: match.home_score.to_i,
        away: match.away_score.to_i,
        result_label: result_label
      }
    end

    def result_label
      return I18n.t("matches.show.result.draw") if match.draw?
      return I18n.t("matches.show.result.home_win", team: result_team_label(match.home_team)) if match.home_score.to_i > match.away_score.to_i
      return I18n.t("matches.show.result.away_win", team: result_team_label(match.away_team)) if match.away_score.to_i > match.home_score.to_i

      I18n.t("matches.show.result.pending")
    end

    def result_team_label(team)
      captain = team.captain
      team_name = captain.present? ? captain.display_name : team.name

      team_name.start_with?("Team ") ? team_name : "Team #{team_name}"
    end

    def time
      {
        started_at: match.started_at,
        ended_at: match.finished_at,
        duration_seconds: duration_seconds
      }
    end

    def duration_seconds
      return match.finished_at.to_i - match.started_at.to_i if match.started_at.present? && match.finished_at.present?
      return match.elapsed_seconds if match.started_at.present?

      0
    end

    def status
      if match.finished?
        I18n.t("statuses.finished")
      elsif match.in_progress?
        I18n.t("statuses.in_progress")
      else
        I18n.t("statuses.not_started")
      end
    end

    def timeline
      timeline_result.events.map do |event|
        goal = event.fetch(:event)

        {
          id: goal.id,
          event_type: goal.own_goal? ? :own_goal : :goal,
          occurred_at_seconds: event.fetch(:occurred_at_seconds),
          team: event.fetch(:scoring_team),
          scorer: event.fetch(:scorer),
          assister: event.fetch(:assister),
          own_goal: goal.own_goal?,
          score_before: event.fetch(:score_before),
          score_after: event.fetch(:score_after),
          first_goal: event.fetch(:is_first_goal),
          equalizer: event.fetch(:is_equalizer),
          go_ahead_goal: event.fetch(:is_go_ahead_goal)
        }
      end
    end

    def score_progression
      [ { team_a: 0, team_b: 0 } ].concat(timeline.map { |event| event.fetch(:score_after) })
    end

    def summary_cards
      [
        summary_card(:goals, goals_count),
        summary_card(:assists, assists_count),
        summary_card(:own_goals, own_goals_count),
        summary_card(:first_goal, first_goal_label),
        summary_card(:last_goal, last_goal_label),
        summary_card(:awards, awards_label)
      ]
    end

    def summary_card(key, value)
      {
        key:,
        label: I18n.t("matches.show.summary_cards.#{key}"),
        value:
      }
    end

    def goals_count
      active_goals.count
    end

    def assists_count
      active_goals.count { |goal| goal.assistant_team_player_id.present? }
    end

    def own_goals_count
      active_goals.count(&:own_goal?)
    end

    def first_goal_label
      first_event = timeline.first
      return I18n.t("common.none") if first_event.blank?

      "#{first_event.fetch(:scorer).name} · #{score_label(first_event.fetch(:score_after))}"
    end

    def last_goal_label
      last_event = timeline.last
      return I18n.t("common.none") if last_event.blank?

      "#{last_event.fetch(:scorer).name} · #{score_label(last_event.fetch(:score_after))}"
    end

    def awards_label
      awards.values.compact.count
    end

    def team_rosters
      [ match.home_team, match.away_team ].map do |team|
        {
          team:,
          players: roster_rows_for(team)
        }
      end
    end

    def roster_rows_for(team)
      team.team_players.includes(:player).sort_by(&:player_name).map do |team_player|
        player_goals = player_goals_for(team_player)
        player_assists = active_goals.count { |goal| goal.assistant_team_player_id == team_player.id }
        player_own_goals = active_goals.count { |goal| goal.own_goal? && goal.scorer_team_player_id == team_player.id }
        player = team_player.player

        {
          team_player:,
          player:,
          goals: player_goals,
          assists: player_assists,
          own_goals: player_own_goals,
          mvp: awards.fetch(:mvp)&.fetch(:player) == player,
          def: awards.fetch(:def)&.fetch(:player) == player
        }
      end
    end

    def player_goals_for(team_player)
      active_goals.count do |goal|
        !goal.own_goal? && goal.scoring_team_id == team_player.team_id && goal.scorer_team_player_id == team_player.id
      end
    end

    def match_summary
      [
        summary_row(:result, result_label),
        summary_row(:first_lead, first_lead_label),
        summary_row(:equalizer, first_equalizer_label),
        summary_row(:own_goals, own_goals_count),
        summary_row(:last_goal, last_goal_time_label),
        summary_row(:start, match.started_at),
        summary_row(:end, match.finished_at),
        summary_row(:duration, duration_seconds)
      ]
    end

    def summary_row(key, value)
      {
        key:,
        label: I18n.t("matches.show.match_summary.#{key}"),
        value:
      }
    end

    def first_lead_label
      first_lead = timeline.find { |event| event.fetch(:go_ahead_goal) }
      return I18n.t("common.none") if first_lead.blank?

      "#{first_lead.fetch(:scorer).display_name} (#{result_team_label(first_lead.fetch(:team))}) · #{score_label(first_lead.fetch(:score_after))}"
    end

    def first_equalizer_label
      first_equalizer = timeline.find { |event| event.fetch(:equalizer) }
      return I18n.t("common.none") if first_equalizer.blank?

      "#{first_equalizer.fetch(:scorer).display_name} (#{result_team_label(first_equalizer.fetch(:team))}) · #{score_label(first_equalizer.fetch(:score_after))}"
    end

    def last_goal_time_label
      last_event = timeline.reverse.find { |event| event.fetch(:occurred_at_seconds).present? }
      return I18n.t("common.none") if last_event.blank?

      last_event.fetch(:occurred_at_seconds)
    end

    def awards
      @awards ||= {
        mvp: award_for(:mvp_player),
        def: award_for(:def_player)
      }
    end

    def award_for(association_name)
      player_counts = match_day_votes
        .map(&association_name)
        .compact
        .tally

      player, votes_count = player_counts.max_by { |candidate, count| [ count, candidate.name ] }
      return nil if player.blank?

      { player:, votes_count: }
    end

    def match_day_votes
      @match_day_votes ||= MatchDayVote
        .joins(match_day_vote_token: :match_day_player)
        .includes(:mvp_player, :def_player)
        .where(match_day_players: { match_day_id: match.match_day_id })
        .to_a
    end

    def active_goals
      @active_goals ||= match.active_match_goals
        .includes(:scoring_team, scorer_team_player: :player, assistant_team_player: :player)
        .to_a
    end

    def score_label(score_hash)
      "#{score_hash.fetch(:team_a)}:#{score_hash.fetch(:team_b)}"
    end
  end
end
