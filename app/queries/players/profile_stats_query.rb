module Players
  class ProfileStatsQuery
    TABS = %w[overview stats matches charts elo synergy awards].freeze

    MatchEntry = Struct.new(
      :match,
      :match_day,
      :team,
      :opponent,
      :date,
      :label,
      :score,
      :result,
      :goals,
      :assists,
      :own_goals,
      :elo_before,
      :elo_delta,
      :elo_after,
      :award_types,
      keyword_init: true
    ) do
      def goals_assists
        goals.to_i + assists.to_i
      end
    end

    Pagination = Struct.new(:items, :page, :per_page, :total_count, :total_pages, :prev_page, :next_page, keyword_init: true)
    AwardEntry = Struct.new(:match_day, :date, :award_type, :votes_count, keyword_init: true)
    Result = Struct.new(
      :player,
      :season,
      :available_seasons,
      :active_tab,
      :summary,
      :record,
      :elo,
      :cumulative,
      :matches,
      :recent_matches,
      :paginated_matches,
      :awards,
      :synergy,
      :chart_data,
      keyword_init: true
    )

    def self.call(player:, season: nil, tab: "overview", page: 1, per_page: 20)
      new(player:, season:, tab:, page:, per_page:).call
    end

    def initialize(player:, season:, tab:, page:, per_page:)
      @player = player
      @requested_season = season
      @tab = TABS.include?(tab.to_s) ? tab.to_s : "overview"
      @page = [ page.to_i, 1 ].max
      @per_page = [ per_page.to_i, 1 ].max
    end

    def call
      Result.new(
        player:,
        season: selected_season,
        available_seasons:,
        active_tab: tab,
        summary:,
        record:,
        elo:,
        cumulative: cumulative_rows,
        matches: match_entries,
        recent_matches: match_entries.first(5),
        paginated_matches: paginate(match_entries),
        awards:,
        synergy:,
        chart_data:
      )
    end

    private

    attr_reader :player, :requested_season, :tab, :page, :per_page

    def available_seasons
      @available_seasons ||= Season.where(id: season_ids).order(starts_on: :desc, created_at: :desc).to_a
    end

    def season_ids
      @season_ids ||= (
        player.match_days.distinct.pluck(:season_id) +
        player_matches_unscope.map { |match| match.match_day.season_id } +
        player.player_season_stats.distinct.pluck(:season_id) +
        player.player_rating_changes.distinct.pluck(:season_id)
      ).compact.uniq
    end

    def selected_season
      @selected_season ||= requested_season || available_seasons.first
    end

    def season_stat
      @season_stat ||= player.player_season_stats.find_by(season: selected_season) if selected_season
    end

    def summary
      @summary ||= {
        current_elo: season_stat&.elo || player.elo,
        matches: match_entries.count,
        goals: goals_count,
        assists: assists_count,
        own_goals: own_goals_count,
        goals_assists: goals_count + assists_count,
        mvp: awards.count { |award| award.award_type == "MVP" },
        def: awards.count { |award| award.award_type == "DEF" },
        wins: record.fetch(:wins),
        draws: record.fetch(:draws),
        losses: record.fetch(:losses),
        win_rate: record.fetch(:win_rate),
        draw_rate: record.fetch(:draw_rate),
        loss_rate: record.fetch(:loss_rate),
        best_win_streak:,
        goals_per_match: rate(goals_count),
        assists_per_match: rate(assists_count),
        goals_assists_per_match: rate(goals_count + assists_count),
        matches_with_goal: match_entries.count { |entry| entry.goals.positive? },
        matches_with_assist: match_entries.count { |entry| entry.assists.positive? },
        matches_with_goals_assists: match_entries.count { |entry| entry.goals_assists.positive? },
        latest_match: match_entries.first,
        latest_award: awards.first,
        season_rank:
      }
    end

    def record
      @record ||= begin
        wins = match_entries.count { |entry| entry.result == Team::RESULT_WIN }
        draws = match_entries.count { |entry| entry.result == Team::RESULT_DRAW }
        losses = match_entries.count { |entry| entry.result == Team::RESULT_LOSS }
        total = match_entries.count

        {
          wins:,
          draws:,
          losses:,
          total:,
          win_rate: percentage(wins, total),
          draw_rate: percentage(draws, total),
          loss_rate: percentage(losses, total)
        }
      end
    end

    def elo
      @elo ||= begin
        values = elo_points.map { |point| point.fetch(:after) }.compact

        {
          current: season_stat&.elo || player.elo,
          highest: values.max,
          lowest: values.min,
          last_change: elo_points.last&.fetch(:delta, nil),
          ranking_position: season_rank,
          points: elo_points
        }
      end
    end

    def season_rank
      @season_rank ||= begin
        return if selected_season.blank?

        stats = PlayerSeasonStat.joins(:player)
          .where(season: selected_season, players: { approval_status: "approved", active: true })
          .where.not(elo: nil)
          .order(elo: :desc)
          .order("players.name ASC")
          .to_a
        index = stats.index { |stat| stat.player_id == player.id }
        index ? index + 1 : nil
      end
    end

    def match_entries
      @match_entries ||= player_matches.filter_map do |match|
        team = player_team_for(match)
        next if team.blank?

        opponent = match.home_team_id == team.id ? match.away_team : match.home_team
        rating_change = rating_change_for(match)
        snapshot = player_team_snapshot(match)

        MatchEntry.new(
          match:,
          match_day: match.match_day,
          team:,
          opponent:,
          date: match.match_day.played_on,
          label: "#{match.match_day.played_on} · ##{match.id}",
          score: score_for(match:, team:),
          result: result_for(match:, team:),
          goals: goals_for(match),
          assists: assists_for(match),
          own_goals: own_goals_for(match),
          elo_before: rating_change&.old_elo_score || snapshot&.elo_before,
          elo_delta: rating_change&.elo_delta || snapshot&.elo_delta,
          elo_after: rating_change&.new_elo_score || snapshot&.elo_after,
          award_types: award_types_for(match.match_day)
        )
      end.sort_by { |entry| [ entry.date, entry.match.started_at || entry.match.finished_at || Time.zone.at(0), entry.match.id ] }.reverse
    end

    def player_matches
      @player_matches ||= begin
        scope = player_matches_unscope
        scope = scope.joins(:match_day).where(match_days: { season_id: selected_season.id }) if selected_season
        scope
      end
    end

    def player_matches_unscope
      @player_matches_unscope ||= Match
        .joins("LEFT JOIN team_players home_profile_team_players ON home_profile_team_players.team_id = matches.home_team_id")
        .joins("LEFT JOIN team_players away_profile_team_players ON away_profile_team_players.team_id = matches.away_team_id")
        .includes(
          :match_day,
          home_team: { team_players: :player },
          away_team: { team_players: :player },
          active_match_goals: [ { scorer_team_player: :player }, { assistant_team_player: :player } ]
        )
        .where(status: Match::STATUS_FINISHED)
        .where("home_profile_team_players.player_id = :player_id OR away_profile_team_players.player_id = :player_id", player_id: player.id)
        .distinct
    end

    def player_team_for(match)
      return match.home_team if match.home_team.team_players.any? { |team_player| team_player.player_id == player.id }

      match.away_team if match.away_team.team_players.any? { |team_player| team_player.player_id == player.id }
    end

    def player_team_snapshot(match)
      player_team_for(match)&.team_players&.find { |team_player| team_player.player_id == player.id }
    end

    def result_for(match:, team:)
      return Team::RESULT_DRAW if match.draw?

      match.winner == team ? Team::RESULT_WIN : Team::RESULT_LOSS
    end

    def score_for(match:, team:)
      team.id == match.home_team_id ? "#{match.home_score}:#{match.away_score}" : "#{match.away_score}:#{match.home_score}"
    end

    def goals_for(match)
      match.active_match_goals.count { |goal| !goal.own_goal? && goal.scorer_team_player.player_id == player.id }
    end

    def assists_for(match)
      match.active_match_goals.count { |goal| !goal.own_goal? && goal.assistant_team_player&.player_id == player.id }
    end

    def own_goals_for(match)
      match.active_match_goals.count { |goal| goal.own_goal? && goal.scorer_team_player.player_id == player.id }
    end

    def rating_changes
      @rating_changes ||= begin
        scope = player.player_rating_changes.where(source_type: PlayerRatingChange::SOURCE_TYPE_MATCH)
        scope = scope.where(season: selected_season) if selected_season
        scope.includes(:match, :match_day).order(:created_at, :id).to_a
      end
    end

    def rating_change_for(match)
      rating_changes_by_match_id.fetch(match.id, nil) || rating_changes_by_match_day_id.fetch(match.match_day_id, nil)
    end

    def rating_changes_by_match_id
      @rating_changes_by_match_id ||= rating_changes.select(&:match_id).index_by(&:match_id)
    end

    def rating_changes_by_match_day_id
      @rating_changes_by_match_day_id ||= rating_changes.reject(&:match_id).index_by(&:match_day_id)
    end

    def goals_count
      @goals_count ||= match_entries.sum(&:goals)
    end

    def assists_count
      @assists_count ||= match_entries.sum(&:assists)
    end

    def own_goals_count
      @own_goals_count ||= match_entries.sum(&:own_goals)
    end

    def rate(value)
      return 0 if match_entries.empty?

      (value.to_f / match_entries.count).round(2)
    end

    def percentage(value, total)
      return 0 if total.zero?

      ((value.to_f / total) * 100).round
    end

    def best_win_streak
      @best_win_streak ||= begin
        current_streak = 0
        best_streak = 0

        match_entries.reverse_each do |entry|
          if entry.result == Team::RESULT_WIN
            current_streak += 1
            best_streak = [ best_streak, current_streak ].max
          else
            current_streak = 0
          end
        end

        best_streak
      end
    end

    def award_types_for(match_day)
      award_types_by_match_day.fetch(match_day.id, [])
    end

    def award_types_by_match_day
      @award_types_by_match_day ||= awards.group_by { |award| award.match_day.id }.transform_values { |entries| entries.map(&:award_type) }
    end

    def awards
      @awards ||= begin
        votes = MatchDayVote
          .joins(match_day_vote_token: { match_day_player: :match_day })
          .includes(match_day_vote_token: { match_day_player: :match_day })
          .where("match_day_votes.mvp_player_id = :player_id OR match_day_votes.def_player_id = :player_id", player_id: player.id)
        votes = votes.where(match_days: { season_id: selected_season.id }) if selected_season

        grouped = Hash.new(0)
        votes.find_each do |vote|
          match_day = vote.match_day_vote_token.match_day_player.match_day
          grouped[[ match_day.id, "MVP" ]] += 1 if vote.mvp_player_id == player.id
          grouped[[ match_day.id, "DEF" ]] += 1 if vote.def_player_id == player.id
        end

        match_days_by_id = MatchDay.where(id: grouped.keys.map(&:first)).index_by(&:id)
        grouped.map do |(match_day_id, award_type), votes_count|
          match_day = match_days_by_id.fetch(match_day_id)
          AwardEntry.new(match_day:, date: match_day.played_on, award_type:, votes_count:)
        end.sort_by { |award| [ award.date, award.award_type ] }.reverse
      end
    end

    def cumulative_rows
      @cumulative_rows ||= begin
        cumulative_goals = 0
        cumulative_assists = 0

        match_entries.reverse.map.with_index(1) do |entry, index|
          cumulative_goals += entry.goals
          cumulative_assists += entry.assists

          {
            label: "Mecz #{index}",
            date: entry.date.to_s,
            match_id: entry.match.id,
            goals: entry.goals,
            assists: entry.assists,
            goals_assists: entry.goals_assists,
            cumulative_goals:,
            cumulative_assists:,
            cumulative_goals_assists: cumulative_goals + cumulative_assists
          }
        end
      end
    end

    def elo_points
      @elo_points ||= begin
        points = rating_changes.map do |change|
          match = change.match
          team = match ? player_team_for(match) : nil

          result = match && team ? result_for(match:, team:) : nil

          {
            label: elo_label_for(change),
            date: change.match_day.played_on.to_s,
            match_id: match&.id,
            match_day_id: change.match_day_id,
            before: change.old_elo_score,
            delta: change.elo_delta,
            after: change.new_elo_score,
            result:,
            result_label: result_label_for(result),
            score: match && team ? score_for(match:, team:) : nil,
            path: match ? Rails.application.routes.url_helpers.match_path(match) : nil
          }
        end

        return points if points.any?

        match_entries.reverse.filter_map do |entry|
          next if entry.elo_after.blank?

          {
            label: entry.label,
            date: entry.date.to_s,
            match_id: entry.match.id,
            match_day_id: entry.match_day.id,
            before: entry.elo_before,
            delta: entry.elo_delta,
            after: entry.elo_after,
            result: entry.result,
            result_label: result_label_for(entry.result),
            score: entry.score,
            path: Rails.application.routes.url_helpers.match_path(entry.match)
          }
        end
      end
    end

    def elo_label_for(change)
      change.match ? "#{change.match_day.played_on} · ##{change.match.id}" : change.match_day.played_on.to_s
    end

    def result_label_for(result)
      return nil if result.blank?

      I18n.t("statuses.#{result}", default: result.to_s)
    end

    def synergy
      @synergy ||= begin
        duos = Synergy::CombinationRankingQuery.call(season: selected_season, combination_size: 2, direction: "best", limit: 50, minimum_shared_matches: 1, player_id: player.id)
        worst = Synergy::CombinationRankingQuery.call(season: selected_season, combination_size: 2, direction: "worst", limit: 50, minimum_shared_matches: 1, player_id: player.id)
        graph_data = Synergy::GraphDataQuery.call(season: selected_season, minimum_shared_matches: 1, player_id: player.id, limit: 20, metric: "shared_matches")

        {
          entries: duos,
          best_partner: duos.first,
          most_played_partner: duos.max_by { |duo| [ duo.shared_matches_count, duo.win_rate.to_i, duo.goals_assists ] },
          best_offensive_partner: duos.max_by { |duo| [ duo.goals_assists, duo.goals, duo.win_rate.to_i ] },
          worst_record_partner: worst.first,
          graph_data:,
          graph_path: Rails.application.routes.url_helpers.relationships_path(
            tab: "graph",
            season_id: selected_season&.id,
            player_id: player.id,
            player_filter: player.name,
            minimum_shared_matches: 1
          )
        }
      end
    end

    def chart_data
      @chart_data ||= {
        elo: {
          labels: elo_points.map { |point| point.fetch(:label) },
          datasets: [
            {
              label: "ELO",
              data: elo_points.map { |point| point.fetch(:after) },
              borderColor: "#7CFF3A",
              backgroundColor: "rgba(124, 255, 58, 0.16)",
              pointBackgroundColor: elo_points.map { |point| elo_point_color(point.fetch(:delta)) },
              pointBorderColor: elo_points.map { |point| elo_point_color(point.fetch(:delta)) },
              pointHoverBorderColor: elo_points.map { |point| elo_point_color(point.fetch(:delta)) },
              segmentByDelta: true,
              tension: 0
            }
          ],
          points_meta: elo_points
        },
        record: {
          labels: [ "Wygrane", "Remisy", "Porażki" ],
          values: [ record.fetch(:wins), record.fetch(:draws), record.fetch(:losses) ],
          datasets: [
            {
              data: [ record.fetch(:wins), record.fetch(:draws), record.fetch(:losses) ],
              backgroundColor: [ "#22C55E", "#94A3B8", "#EF4444" ],
              borderColor: "#0B1728"
            }
          ]
        },
        cumulative_goals: line_chart_for("Gole", :cumulative_goals, "#7CFF3A"),
        cumulative_assists: line_chart_for("Asysty", :cumulative_assists, "#38BDF8"),
        cumulative_goals_assists: {
          labels: cumulative_rows.map { |row| row.fetch(:label) },
          datasets: [
            line_dataset_for("Gole", :cumulative_goals, "#7CFF3A"),
            line_dataset_for("Asysty", :cumulative_assists, "#38BDF8"),
            line_dataset_for("G+A", :cumulative_goals_assists, "#FACC15")
          ]
        }
      }
    end

    def line_chart_for(label, key, color)
      {
        labels: cumulative_rows.map { |row| row.fetch(:label) },
        datasets: [ line_dataset_for(label, key, color) ]
      }
    end

    def line_dataset_for(label, key, color)
      {
        label:,
        data: cumulative_rows.map { |row| row.fetch(key) },
        borderColor: color,
        backgroundColor: "#{color}22",
        stepped: true,
        tension: 0
      }
    end

    def elo_point_color(delta)
      return "#94A3B8" if delta.to_i.zero?

      delta.to_i.positive? ? "#22C55E" : "#EF4444"
    end

    def paginate(items)
      total_count = items.count
      total_pages = (total_count.to_f / per_page).ceil
      current_page = [ page, [ total_pages, 1 ].max ].min
      offset = (current_page - 1) * per_page

      Pagination.new(
        items: items.slice(offset, per_page) || [],
        page: current_page,
        per_page:,
        total_count:,
        total_pages:,
        prev_page: current_page > 1 ? current_page - 1 : nil,
        next_page: current_page < total_pages ? current_page + 1 : nil
      )
    end
  end
end
