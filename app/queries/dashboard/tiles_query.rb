module Dashboard
  class TilesQuery
    Result = Struct.new(
      :current_season,
      :nearest_match_day,
      :day_balance,
      :approved_active_players_count,
      :approved_players_count,
      :pending_players_count,
      :top_elo,
      :top_scorers,
      :top_assists,
      :top_mvp,
      :top_def,
      :open_vote_tokens_count,
      :cast_vote_tokens_count,
      :best_duo_summary,
      keyword_init: true
    ) do
      def ranked_top_elo
        ranked_entries(top_elo, :elo)
      end

      def ranked_top_scorers
        ranked_entries(top_scorers, :goals)
      end

      def ranked_top_assists
        ranked_entries(top_assists, :assists)
      end

      private

      def ranked_entries(entries, value_method)
        Rankings::CompetitionRanker.call(entries:, value_method:)
      end
    end

    def self.call(admin_signed_in:)
      new(admin_signed_in:).call
    end

    def initialize(admin_signed_in:)
      @admin_signed_in = admin_signed_in
    end

    def call
      Result.new(
        current_season:,
        nearest_match_day:,
        day_balance:,
        approved_active_players_count: approved_active_players.count,
        approved_players_count: Player.approved.count,
        pending_players_count:,
        top_elo: leaderboard_entries(:elo_ranking),
        top_scorers: leaderboard_entries(:top_scorers, minimum_column: :goals),
        top_assists: leaderboard_entries(:top_assistants, minimum_column: :assists),
        top_mvp: leaderboard_entries(:top_mvp, minimum_column: :mvp_votes_count, limit: 1),
        top_def: leaderboard_entries(:top_def, minimum_column: :def_votes_count, limit: 1),
        open_vote_tokens_count:,
        cast_vote_tokens_count:,
        best_duo_summary:
      )
    end

    private

    attr_reader :admin_signed_in

    def current_season
      @current_season ||= Season.current_active
    end

    def approved_active_players
      @approved_active_players ||= Player.approved.active.order(:name)
    end

    def pending_players_count
      return nil unless admin_signed_in

      Player.pending.count
    end

    def nearest_match_day
      return nil if current_season.blank?

      @nearest_match_day ||= upcoming_match_day || latest_match_day
    end

    def upcoming_match_day
      current_season
        .match_days
        .where(status: %w[setup ready in_progress])
        .where("played_on >= ?", Date.current)
        .order(:played_on, :id)
        .first
    end

    def latest_match_day
      current_season.match_days.order(played_on: :desc, id: :desc).first
    end

    def day_balance
      @day_balance ||= Dashboard::DayBalanceQuery.call(season: current_season)
    end

    def leaderboards
      return nil if current_season.blank?

      @leaderboards ||= Seasons::PublicLeaderboardQuery.call(season: current_season)
    end

    def leaderboard_entries(name, minimum_column: nil, limit: 5)
      return [] if leaderboards.blank?

      entries = leaderboards.public_send(name).first(limit)
      return entries.to_a if minimum_column.blank?

      entries.select { |entry| entry.public_send(minimum_column).to_i.positive? }
    end

    def open_vote_tokens_count
      return 0 if current_season.blank?

      vote_tokens_scope
        .where(used_at: nil)
        .where("match_day_vote_tokens.expires_at > ?", Time.current)
        .count
    end

    def cast_vote_tokens_count
      return 0 if current_season.blank?

      vote_tokens_scope.where.not(used_at: nil).count
    end

    def vote_tokens_scope
      MatchDayVoteToken
        .joins(match_day_player: :match_day)
        .where(match_days: { season_id: current_season.id })
    end

    def best_duo_summary
      @best_duo_summary ||= Relationships::BestDuoSummary.call(season: current_season)
    end
  end
end
