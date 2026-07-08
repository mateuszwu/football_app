require "set"

module Seasons
  class ShowQuery
    Result = Struct.new(:season, :summary, :match_days, :sidebar, :sort_direction, keyword_init: true)
    Summary = Struct.new(
      :match_days_count,
      :matches_count,
      :players_count,
      :goals_count,
      :assists_count,
      :own_goals_count,
      :total_duration_seconds,
      :average_players_per_match_day,
      keyword_init: true
    )
    Sidebar = Struct.new(:first_match_day_date, :last_match_day_date, :average_match_duration_seconds, :most_active_players, keyword_init: true)
    MatchDayRow = Struct.new(
      :match_day,
      :date,
      :status,
      :matches_count,
      :players_count,
      :teams_count,
      :team_names,
      :goals_count,
      :assists_count,
      :own_goals_count,
      :total_duration_seconds,
      :top_scorer,
      :top_assistant,
      :mvp,
      :def,
      keyword_init: true
    )
    PlayerActivity = Struct.new(:player, :matches_count, keyword_init: true)
    PlayerHighlight = Struct.new(:player, :value, keyword_init: true)

    SORT_ASC = "asc"
    SORT_DESC = "desc"
    SORT_DIRECTIONS = [ SORT_ASC, SORT_DESC ].freeze

    def self.call(season:, sort_direction: SORT_DESC)
      new(season:, sort_direction:).call
    end

    def initialize(season:, sort_direction:)
      @season = season
      @sort_direction = SORT_DIRECTIONS.include?(sort_direction.to_s) ? sort_direction.to_s : SORT_DESC
    end

    def call
      Result.new(
        season:,
        summary: summary,
        match_days: match_day_rows,
        sidebar: sidebar,
        sort_direction: sort_direction
      )
    end

    private

    attr_reader :season, :sort_direction

    def summary
      Summary.new(
        match_days_count: match_days_with_matches.count,
        matches_count: season_matches.count,
        players_count: season_player_ids.count,
        goals_count: active_goals.count,
        assists_count: active_goals.count { |goal| goal.assistant_team_player_id.present? },
        own_goals_count: active_goals.count(&:own_goal?),
        total_duration_seconds: finished_match_durations.sum,
        average_players_per_match_day: average_players_per_match_day
      )
    end

    def sidebar
      Sidebar.new(
        first_match_day_date: match_day_dates.first,
        last_match_day_date: match_day_dates.last,
        average_match_duration_seconds: average_match_duration_seconds,
        most_active_players: most_active_players
      )
    end

    def match_day_rows
      sorted_match_days.map do |match_day|
        goals = goals_by_match_day_id.fetch(match_day.id, [])
        day_matches = matches_by_match_day_id.fetch(match_day.id, [])

        MatchDayRow.new(
          match_day:,
          date: match_day.played_on,
          status: match_day.status,
          matches_count: day_matches.count,
          players_count: player_ids_for_matches(day_matches).count,
          teams_count: team_ids_for_matches(day_matches).count,
          team_names: team_names_for_matches(day_matches),
          goals_count: goals.count,
          assists_count: goals.count { |goal| goal.assistant_team_player_id.present? },
          own_goals_count: goals.count(&:own_goal?),
          total_duration_seconds: day_matches.sum { |match| duration_for(match).to_i },
          top_scorer: top_player_from(goal_counts_for(goals), :goals),
          top_assistant: top_player_from(assist_counts_for(goals), :assists),
          mvp: award_for(match_day, :mvp_player),
          def: award_for(match_day, :def_player)
        )
      end
    end

    def average_players_per_match_day
      return nil if match_days_with_matches.empty?

      (match_days_with_matches.sum { |match_day| player_ids_for_matches(matches_by_match_day_id.fetch(match_day.id, [])).count }.to_f / match_days_with_matches.count).round(1)
    end

    def average_match_duration_seconds
      return nil if finished_match_durations.empty?

      finished_match_durations.sum / finished_match_durations.count
    end

    def most_active_players
      player_match_ids
        .filter_map do |player_id, match_ids|
          player = players_by_id.fetch(player_id, nil)
          next if player.blank? || !public_player?(player)

          PlayerActivity.new(player:, matches_count: match_ids.count)
        end
        .sort_by { |row| [ -row.matches_count, row.player.name ] }
        .first(5)
    end

    def top_player_from(counts, value_key)
      player_id, value = counts.sort_by { |candidate_player_id, candidate_value| [ -candidate_value, players_by_id.fetch(candidate_player_id).name ] }.first
      return nil if player_id.blank? || value.to_i.zero?

      player = players_by_id.fetch(player_id)
      return nil unless public_player?(player)

      PlayerHighlight.new(player:, value: value_label(value_key, value))
    end

    def value_label(key, value)
      case key
      when :goals
        I18n.t("dashboard.labels.goals_count", count: value)
      when :assists
        I18n.t("dashboard.labels.assists_count", count: value)
      else
        value.to_s
      end
    end

    def award_for(match_day, association_name)
      votes = votes_by_match_day_id.fetch(match_day.id, [])
      player, votes_count = votes.map(&association_name).compact.tally.sort_by { |candidate, count| [ -count, candidate.name ] }.first
      return nil if player.blank? || !public_player?(player)

      PlayerHighlight.new(player:, value: I18n.t("dashboard.labels.votes", count: votes_count))
    end

    def goal_counts_for(goals)
      goals.reject(&:own_goal?).each_with_object(Hash.new(0)) do |goal, counts|
        counts[goal.scorer_team_player.player_id] += 1
      end
    end

    def assist_counts_for(goals)
      goals.each_with_object(Hash.new(0)) do |goal, counts|
        counts[goal.assistant_team_player.player_id] += 1 if goal.assistant_team_player_id.present?
      end
    end

    def sorted_match_days
      match_days_with_matches.sort_by { |match_day| [ match_day.played_on, match_day.id ] }.then do |rows|
        sort_direction == SORT_ASC ? rows : rows.reverse
      end
    end

    def match_day_dates
      @match_day_dates ||= match_days_with_matches.map(&:played_on).sort
    end

    def match_days_with_matches
      @match_days_with_matches ||= season.match_days
        .includes(:matches)
        .select { |match_day| matches_by_match_day_id.fetch(match_day.id, []).any? }
    end

    def season_matches
      @season_matches ||= Match
        .joins(:match_day)
        .where(match_days: { season_id: season.id })
        .includes(home_team: { team_players: :player }, away_team: { team_players: :player })
        .to_a
    end

    def matches_by_match_day_id
      @matches_by_match_day_id ||= season_matches.group_by(&:match_day_id)
    end

    def active_goals
      @active_goals ||= MatchGoal
        .active
        .joins(match: :match_day)
        .where(match_days: { season_id: season.id })
        .includes(:match, scorer_team_player: :player, assistant_team_player: :player)
        .to_a
    end

    def goals_by_match_day_id
      @goals_by_match_day_id ||= active_goals.group_by { |goal| goal.match.match_day_id }
    end

    def votes_by_match_day_id
      @votes_by_match_day_id ||= MatchDayVote
        .joins(match_day_vote_token: :match_day_player)
        .includes(:mvp_player, :def_player, match_day_vote_token: :match_day_player)
        .where(match_day_players: { match_day_id: season.match_day_ids })
        .group_by { |vote| vote.match_day_vote_token.match_day_player.match_day_id }
    end

    def player_match_ids
      @player_match_ids ||= season_matches.each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) do |match, map|
        [ match.home_team, match.away_team ].each do |team|
          team.team_players.each do |team_player|
            map[team_player.player_id] << match.id
          end
        end
      end
    end

    def season_player_ids
      @season_player_ids ||= player_match_ids.keys.to_set
    end

    def players_by_id
      @players_by_id ||= Player.where(id: season_player_ids.to_a).index_by(&:id)
    end

    def player_ids_for_matches(matches)
      matches.each_with_object(Set.new) do |match, ids|
        [ match.home_team, match.away_team ].each do |team|
          team.team_players.each { |team_player| ids << team_player.player_id }
        end
      end
    end

    def team_ids_for_matches(matches)
      matches.each_with_object(Set.new) do |match, ids|
        ids << match.home_team_id
        ids << match.away_team_id
      end
    end

    def team_names_for_matches(matches)
      matches.each_with_object(Set.new) do |match, names|
        names << match.home_team.name
        names << match.away_team.name
      end.to_a.sort
    end

    def finished_match_durations
      @finished_match_durations ||= season_matches.filter_map { |match| duration_for(match) }
    end

    def duration_for(match)
      return nil if match.started_at.blank? || match.finished_at.blank?

      match.elapsed_seconds(match.finished_at)
    end

    def public_player?(player)
      player.active? && player.approval_status == "approved"
    end
  end
end
