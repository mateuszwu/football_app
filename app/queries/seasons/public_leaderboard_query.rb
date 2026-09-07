module Seasons
  class PublicLeaderboardQuery
    DEFAULT_ATTENDANCE_PERCENT = 25
    ATTENDANCE_PERCENT_OPTIONS = [ 0, 10, 15, 20, 25, 30, 50 ].freeze

    Leaderboards = Struct.new(
      :top_scorers,
      :top_assistants,
      :top_mvp,
      :top_def,
      :elo_ranking,
      :goals_assists_ranking,
      :record_ranking,
      :attendance_percent,
      :season_matches_count,
      :minimum_matches,
      keyword_init: true
    ) do
      def ranked_top_scorers
        ranked_entries(top_scorers, :goals)
      end

      def ranked_top_assistants
        ranked_entries(top_assistants, :assists)
      end

      def ranked_top_mvp
        ranked_entries(top_mvp, :mvp_votes_count)
      end

      def ranked_top_def
        ranked_entries(top_def, :def_votes_count)
      end

      def ranked_elo
        ranked_entries(elo_ranking, :elo)
      end

      def ranked_goals_assists
        ranked_entries(goals_assists_ranking, ->(entry) { entry.goals.to_i + entry.assists.to_i })
      end

      def ranked_record
        ranked_entries(record_ranking, ->(entry) { entry.win_rate_value })
      end

      private

      def ranked_entries(entries, value_method)
        Rankings::CompetitionRanker.call(entries:, value_method:)
      end
    end

    def self.call(season:, attendance_percent: DEFAULT_ATTENDANCE_PERCENT)
      new(season:, attendance_percent:).call
    end

    def self.normalize_attendance_percent(value)
      return DEFAULT_ATTENDANCE_PERCENT if value.blank?

      Integer(value.to_s, 10).clamp(0, 100)
    rescue ArgumentError, TypeError
      DEFAULT_ATTENDANCE_PERCENT
    end

    def initialize(season:, attendance_percent: DEFAULT_ATTENDANCE_PERCENT)
      @season = season
      @attendance_percent = self.class.normalize_attendance_percent(attendance_percent)
    end

    def call
      Leaderboards.new(
        top_scorers: attendance_filtered_leaderboard_scope
          .order(goals: :desc)
          .order(Arel.sql("goals_per_match_value DESC"))
          .order(assists: :desc)
          .order(Arel.sql("matches_played_count ASC"))
          .order("players.name": :asc)
          .to_a,
        top_assistants: attendance_filtered_leaderboard_scope
          .order(assists: :desc)
          .order(Arel.sql("assists_per_match_value DESC"))
          .order(goals: :desc)
          .order(Arel.sql("matches_played_count ASC"))
          .order("players.name": :asc)
          .to_a,
        top_mvp: leaderboard_scope
          .where("player_season_stats.mvp_votes_count > 0")
          .order(mvp_votes_count: :desc)
          .order(Arel.sql("matches_played_count ASC"))
          .order("players.name": :asc)
          .to_a,
        top_def: leaderboard_scope
          .where("player_season_stats.def_votes_count > 0")
          .order(def_votes_count: :desc)
          .order(Arel.sql("matches_played_count ASC"))
          .order("players.name": :asc)
          .to_a,
        elo_ranking: leaderboard_scope
          .order(Arel.sql("COALESCE(player_season_stats.elo, 0) DESC"))
          .order(Arel.sql("COALESCE(last_elo_delta_value, 0) DESC"))
          .order("players.name": :asc)
          .to_a,
        goals_assists_ranking: attendance_filtered_leaderboard_scope
          .order(Arel.sql("(player_season_stats.goals + player_season_stats.assists) DESC"))
          .order(Arel.sql("goals_assists_per_match_value DESC"))
          .order(goals: :desc)
          .order(assists: :desc)
          .order(Arel.sql("matches_played_count ASC"))
          .order("players.name": :asc)
          .to_a,
        record_ranking: leaderboard_scope
          .order(Arel.sql("win_rate_value DESC"))
          .order(Arel.sql("wins_count DESC"))
          .order(Arel.sql("goal_difference_value DESC"))
          .order(Arel.sql("matches_played_count DESC"))
          .order("players.name": :asc)
          .to_a,
        attendance_percent:,
        season_matches_count:,
        minimum_matches:
      )
    end

    private

    attr_reader :season, :attendance_percent

    def season_matches_count
      @season_matches_count ||= season.match_days
        .joins(:matches)
        .where(matches: { status: Match::STATUS_FINISHED })
        .count
    end

    def minimum_matches
      @minimum_matches ||= (season_matches_count * attendance_percent / 100.0).floor
    end

    def leaderboard_scope
      @leaderboard_scope ||= season.player_season_stats
                                  .select("player_season_stats.*")
                                  .select(leaderboard_metric_selects)
                                  .joins(:player)
                                  .merge(Player.approved.active)
                                  .includes(:player)
    end

    def attendance_filtered_leaderboard_scope
      @attendance_filtered_leaderboard_scope ||= leaderboard_scope.where(attendance_filter_condition)
    end

    def attendance_filter_condition
      Arel::Nodes::Grouping.new(matches_count_subquery.ast).gteq(minimum_matches)
    end

    def matches_count_subquery
      player_season_stats_table = PlayerSeasonStat.arel_table
      team_players_table = TeamPlayer.arel_table
      matches_table = Match.arel_table
      match_days_table = MatchDay.arel_table

      team_players_table
        .project(team_players_table[:id].count)
        .join(matches_table)
        .on(
          matches_table[:home_team_id].eq(team_players_table[:team_id])
            .or(matches_table[:away_team_id].eq(team_players_table[:team_id]))
        )
        .join(match_days_table)
        .on(match_days_table[:id].eq(matches_table[:match_day_id]))
        .where(
          team_players_table[:player_id].eq(player_season_stats_table[:player_id])
            .and(match_days_table[:season_id].eq(player_season_stats_table[:season_id]))
            .and(matches_table[:status].eq(Match::STATUS_FINISHED))
        )
    end

    def leaderboard_metric_selects
      [
        matches_played_select,
        last_elo_delta_select,
        wins_select,
        draws_select,
        losses_select,
        goal_difference_select,
        goals_per_match_select,
        assists_per_match_select,
        goals_assists_per_match_select,
        win_rate_select
      ].join(", ")
    end

    def matches_played_select
      <<~SQL.squish
        (
          SELECT COUNT(*)
          FROM team_players
          INNER JOIN matches ON matches.home_team_id = team_players.team_id OR matches.away_team_id = team_players.team_id
          INNER JOIN match_days ON match_days.id = matches.match_day_id
          WHERE team_players.player_id = player_season_stats.player_id
          AND match_days.season_id = player_season_stats.season_id
          AND matches.status = '#{Match::STATUS_FINISHED}'
        ) AS matches_played_count
      SQL
    end

    def last_elo_delta_select
      <<~SQL.squish
        (
          SELECT SUM(player_rating_changes.elo_delta)
          FROM player_rating_changes
          INNER JOIN match_days ON match_days.id = player_rating_changes.match_day_id
          WHERE player_rating_changes.player_id = player_season_stats.player_id
          AND player_rating_changes.season_id = player_season_stats.season_id
          AND player_rating_changes.rating_scope = '#{PlayerRatingChange::RATING_SCOPE_SEASON}'
          AND player_rating_changes.source_type = '#{PlayerRatingChange::SOURCE_TYPE_MATCH}'
          AND player_rating_changes.elo_delta IS NOT NULL
          GROUP BY match_days.played_on
          ORDER BY match_days.played_on DESC
          LIMIT 1
        ) AS last_elo_delta_value
      SQL
    end

    def wins_select
      "#{record_sum_sql(home_condition: 'matches.home_score > matches.away_score', away_condition: 'matches.away_score > matches.home_score')} AS wins_count"
    end

    def draws_select
      "#{record_sum_sql(home_condition: 'matches.home_score = matches.away_score', away_condition: 'matches.away_score = matches.home_score')} AS draws_count"
    end

    def losses_select
      "#{record_sum_sql(home_condition: 'matches.home_score < matches.away_score', away_condition: 'matches.away_score < matches.home_score')} AS losses_count"
    end

    def goal_difference_select
      <<~SQL.squish
        COALESCE((
          SELECT SUM(
            CASE
              WHEN team_players.team_id = matches.home_team_id THEN matches.home_score - matches.away_score
              WHEN team_players.team_id = matches.away_team_id THEN matches.away_score - matches.home_score
              ELSE 0
            END
          )
          FROM team_players
          INNER JOIN matches ON matches.home_team_id = team_players.team_id OR matches.away_team_id = team_players.team_id
          INNER JOIN match_days ON match_days.id = matches.match_day_id
          WHERE team_players.player_id = player_season_stats.player_id
          AND match_days.season_id = player_season_stats.season_id
          AND matches.status = '#{Match::STATUS_FINISHED}'
        ), 0) AS goal_difference_value
      SQL
    end

    def goals_per_match_select
      "(CASE WHEN (#{matches_count_inner_sql}) = 0 THEN 0.0 ELSE player_season_stats.goals * 1.0 / (#{matches_count_inner_sql}) END) AS goals_per_match_value"
    end

    def assists_per_match_select
      "(CASE WHEN (#{matches_count_inner_sql}) = 0 THEN 0.0 ELSE player_season_stats.assists * 1.0 / (#{matches_count_inner_sql}) END) AS assists_per_match_value"
    end

    def goals_assists_per_match_select
      "(CASE WHEN (#{matches_count_inner_sql}) = 0 THEN 0.0 ELSE (player_season_stats.goals + player_season_stats.assists) * 1.0 / (#{matches_count_inner_sql}) END) AS goals_assists_per_match_value"
    end

    def win_rate_select
      "(CASE WHEN (#{matches_count_inner_sql}) = 0 THEN 0.0 ELSE (#{wins_inner_sql}) * 100.0 / (#{matches_count_inner_sql}) END) AS win_rate_value"
    end

    def record_sum_sql(home_condition:, away_condition:)
      <<~SQL.squish
        COALESCE((
          SELECT SUM(
            CASE
              WHEN team_players.team_id = matches.home_team_id AND #{home_condition} THEN 1
              WHEN team_players.team_id = matches.away_team_id AND #{away_condition} THEN 1
              ELSE 0
            END
          )
          FROM team_players
          INNER JOIN matches ON matches.home_team_id = team_players.team_id OR matches.away_team_id = team_players.team_id
          INNER JOIN match_days ON match_days.id = matches.match_day_id
          WHERE team_players.player_id = player_season_stats.player_id
          AND match_days.season_id = player_season_stats.season_id
          AND matches.status = '#{Match::STATUS_FINISHED}'
        ), 0)
      SQL
    end

    def matches_count_inner_sql
      <<~SQL.squish
        SELECT COUNT(*)
        FROM team_players
        INNER JOIN matches ON matches.home_team_id = team_players.team_id OR matches.away_team_id = team_players.team_id
        INNER JOIN match_days ON match_days.id = matches.match_day_id
        WHERE team_players.player_id = player_season_stats.player_id
        AND match_days.season_id = player_season_stats.season_id
        AND matches.status = '#{Match::STATUS_FINISHED}'
      SQL
    end

    def wins_inner_sql
      record_sum_sql(home_condition: "matches.home_score > matches.away_score", away_condition: "matches.away_score > matches.home_score")
    end
  end
end
