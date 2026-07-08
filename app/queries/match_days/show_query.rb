require "set"

module MatchDays
  class ShowQuery
    Result = Struct.new(:match_day, :season, :summary, :matches, :leaders, :players_table, keyword_init: true)

    MatchRow = Struct.new(
      :match,
      :label,
      :start_time,
      :end_time,
      :duration_seconds,
      :home_team,
      :away_team,
      :home_score,
      :away_score,
      :result_label,
      :events,
      keyword_init: true
    )

    EventRow = Struct.new(:minute_seconds, :scorer, :assister, :team, :own_goal, :score_after, keyword_init: true)
    LeaderRow = Struct.new(:label, :player, :value, :details, keyword_init: true)
    PlayerRow = Struct.new(:player, :matches_played, :goals, :assists, :goals_assists, keyword_init: true)

    def self.call(match_day:)
      new(match_day:).call
    end

    def initialize(match_day:)
      @match_day = match_day
    end

    def call
      Result.new(
        match_day:,
        season: match_day.season,
        summary: summary,
        matches: match_rows,
        leaders: leaders,
        players_table: players_table
      )
    end

    private

    attr_reader :match_day

    def summary
      {
        matches_count: finished_matches.count,
        goals_count: active_goals.count,
        assists_count: active_goals.count { |goal| goal.assistant_team_player_id.present? },
        own_goals_count: active_goals.count(&:own_goal?),
        players_count: participating_players.count,
        total_duration_seconds: finished_matches.sum { |match| match.elapsed_seconds(match.finished_at) }
      }
    end

    def match_rows
      finished_matches.each_with_index.map do |match, index|
        timeline = Stats::MatchTimelineQuery.call(match:)

        MatchRow.new(
          match:,
          label: I18n.t("match_days.show.match_label", number: index + 1),
          start_time: match.started_at,
          end_time: match.finished_at,
          duration_seconds: match.elapsed_seconds(match.finished_at),
          home_team: match.home_team,
          away_team: match.away_team,
          home_score: match.home_score.to_i,
          away_score: match.away_score.to_i,
          result_label: result_label_for(match),
          events: timeline.events.map { |event| event_row_for(event) }
        )
      end
    end

    def leaders
      {
        top_scorer: leader_from(player_goal_counts, :top_scorer, :goals_count),
        top_assistant: leader_from(player_assist_counts, :top_assistant, :assists_count),
        top_ga: top_goals_assists_leader,
        mvp: award_leader(:mvp_player, :mvp),
        def: award_leader(:def_player, :def)
      }
    end

    def leader_from(counts, label_key, value_key)
      player, value = sorted_counts(counts).first
      return nil if player.blank? || value.to_i.zero?

      LeaderRow.new(
        label: I18n.t("match_days.show.leaders.#{label_key}"),
        player:,
        value: I18n.t("match_days.show.leader_values.#{value_key}", count: value),
        details: nil
      )
    end

    def top_goals_assists_leader
      player, value = sorted_counts(player_goals_assists_counts).first
      return nil if player.blank? || value.to_i.zero?

      goals = player_goal_counts.fetch(player, 0)
      assists = player_assist_counts.fetch(player, 0)

      LeaderRow.new(
        label: I18n.t("match_days.show.leaders.top_ga"),
        player:,
        value: I18n.t("match_days.show.leader_values.goals_assists_count", count: value),
        details: I18n.t("match_days.show.leader_values.goals_assists_split", goals:, assists:)
      )
    end

    def award_leader(association_name, label_key)
      player, value = sorted_counts(match_day_votes.map(&association_name).compact.tally).first
      return nil if player.blank? || value.to_i.zero?

      LeaderRow.new(
        label: I18n.t("match_days.show.leaders.#{label_key}"),
        player:,
        value: I18n.t("match_days.show.leader_values.votes_count", count: value),
        details: nil
      )
    end

    def players_table
      participating_players.map do |player|
        goals = player_goal_counts.fetch(player, 0)
        assists = player_assist_counts.fetch(player, 0)

        PlayerRow.new(
          player:,
          matches_played: player_match_ids.fetch(player, Set.new).count,
          goals:,
          assists:,
          goals_assists: goals + assists
        )
      end.sort_by { |row| [ -row.goals_assists, -row.goals, -row.assists, row.player.name ] }
    end

    def result_label_for(match)
      return I18n.t("match_days.show.result.draw") if match.draw?

      I18n.t("match_days.show.result.win", team: match.winner.name)
    end

    def event_row_for(timeline_event)
      goal = timeline_event.fetch(:event)

      EventRow.new(
        minute_seconds: timeline_event.fetch(:occurred_at_seconds),
        scorer: timeline_event.fetch(:scorer),
        assister: timeline_event.fetch(:assister),
        team: timeline_event.fetch(:scoring_team),
        own_goal: goal.own_goal?,
        score_after: timeline_event.fetch(:score_after)
      )
    end

    def player_goal_counts
      @player_goal_counts ||= active_goals
        .reject(&:own_goal?)
        .map(&:scorer)
        .tally
    end

    def player_assist_counts
      @player_assist_counts ||= active_goals
        .filter_map(&:assistant)
        .tally
    end

    def player_goals_assists_counts
      @player_goals_assists_counts ||= participating_players.to_h do |player|
        [ player, player_goal_counts.fetch(player, 0) + player_assist_counts.fetch(player, 0) ]
      end
    end

    def participating_players
      @participating_players ||= player_match_ids.keys.sort_by(&:name)
    end

    def player_match_ids
      @player_match_ids ||= begin
        map = Hash.new { |hash, key| hash[key] = Set.new }

        finished_matches.each do |match|
          [ match.home_team, match.away_team ].each do |team|
            team.team_players.each do |team_player|
              map[team_player.player] << match.id
            end
          end
        end

        map
      end
    end

    def sorted_counts(counts)
      counts.sort_by { |player, value| [ -value.to_i, player.name ] }
    end

    def active_goals
      @active_goals ||= finished_matches.flat_map do |match|
        match.active_match_goals.to_a
      end
    end

    def match_day_votes
      @match_day_votes ||= MatchDayVote
        .joins(match_day_vote_token: :match_day_player)
        .includes(:mvp_player, :def_player)
        .where(match_day_players: { match_day_id: match_day.id })
        .to_a
    end

    def finished_matches
      @finished_matches ||= match_day.matches
        .where(status: Match::STATUS_FINISHED)
        .includes(
          :match_day,
          home_team: { team_players: :player },
          away_team: { team_players: :player },
          active_match_goals: [ :scoring_team, { scorer_team_player: :player, assistant_team_player: :player } ]
        )
        .sort_by { |match| [ match.started_at || Time.zone.at(0), match.id ] }
    end
  end
end
