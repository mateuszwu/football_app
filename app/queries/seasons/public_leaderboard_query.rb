module Seasons
  class PublicLeaderboardQuery
    Leaderboards = Struct.new(
      :top_scorers,
      :top_assistants,
      :top_mvp,
      :top_def,
      :elo_ranking,
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

      private

      def ranked_entries(entries, value_method)
        Rankings::CompetitionRanker.call(entries:, value_method:)
      end
    end

    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      Leaderboards.new(
        top_scorers: leaderboard_scope.order(goals: :desc, assists: :desc, "players.name": :asc),
        top_assistants: leaderboard_scope.order(assists: :desc, goals: :desc, "players.name": :asc),
        top_mvp: leaderboard_scope.order(mvp_votes_count: :desc, goals: :desc, "players.name": :asc),
        top_def: leaderboard_scope.order(def_votes_count: :desc, goals: :desc, "players.name": :asc),
        elo_ranking: leaderboard_scope.order(Arel.sql("COALESCE(player_season_stats.elo, 0) DESC"), "players.name" => :asc)
      )
    end

    private

    attr_reader :season

    def leaderboard_scope
      @leaderboard_scope ||= season.player_season_stats
                                  .joins(:player)
                                  .merge(Player.approved.active)
                                  .includes(:player)
    end
  end
end
