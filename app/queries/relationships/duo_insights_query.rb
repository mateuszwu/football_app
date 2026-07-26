module Relationships
  class DuoInsightsQuery
    Summary = Struct.new(
      :player_a,
      :player_b,
      :shared_match_days_count,
      :shared_matches_count,
      :wins,
      :draws,
      :losses,
      :goals,
      :assists,
      :mutual_assists,
      keyword_init: true
    ) do
      def empty?
        player_a.blank? || player_b.blank?
      end

      def match_level?
        shared_matches_count.to_i.positive?
      end

      def shared_count
        match_level? ? shared_matches_count.to_i : shared_match_days_count.to_i
      end

      def win_rate
        return nil unless match_level?

        ((wins.to_f / shared_matches_count) * 100).round
      end

      def offense_total
        goals.to_i + assists.to_i
      end

      def direct_offense_total
        mutual_assists.to_i * 2
      end

      def overall_score
        wins.to_i * 3 + draws.to_i + offense_total
      end

      alias duet_score overall_score
    end

    Result = Struct.new(
      :summaries,
      :best_overall_duo,
      :most_played_duo,
      :best_win_rate_duo,
      :best_offensive_duo,
      keyword_init: true
    )

    def self.call(season: nil, players: Player.approved.active)
      new(season:, players:).call
    end

    def initialize(season:, players:)
      @season = season
      @players = players.to_a
    end

    def call
      built_summaries = summaries
      match_level_available = built_summaries.any?(&:match_level?)

      Result.new(
        summaries: ranked_summaries(built_summaries, match_level_available:),
        best_overall_duo: best_overall_duo(built_summaries, match_level_available:),
        most_played_duo: most_played_duo(built_summaries, match_level_available:),
        best_win_rate_duo: best_win_rate_duo(built_summaries, match_level_available:),
        best_offensive_duo: best_offensive_duo(built_summaries, match_level_available:)
      )
    end

    private

    attr_reader :season, :players

    def summaries
      Relationships::PairStatsQuery.call(season:, players:).map { |pair_stats| build_summary(pair_stats) }
    end

    def build_summary(pair_stats)
      player_a, player_b = pair_stats.players.sort_by(&:name)

      Summary.new(
        player_a:,
        player_b:,
        shared_match_days_count: pair_stats.shared_match_days_count,
        shared_matches_count: pair_stats.shared_matches_count,
        wins: pair_stats.wins,
        draws: pair_stats.draws,
        losses: pair_stats.losses,
        goals: pair_stats.goals,
        assists: pair_stats.assists,
        mutual_assists: pair_stats.mutual_assists
      )
    end

    def best_overall_duo(summaries, match_level_available:)
      summaries
        .select { |summary| eligible_for_balanced_duo?(summary, match_level_available:) }
        .sort_by { |summary| [ -summary.overall_score, -play_count_for(summary, match_level_available:), summary.player_a.name, summary.player_b.name ] }
        .first
    end

    def most_played_duo(summaries, match_level_available:)
      summaries
        .sort_by { |summary| [ -play_count_for(summary, match_level_available:), -summary.win_rate.to_i, -summary.offense_total, summary.player_a.name, summary.player_b.name ] }
        .first
    end

    def best_win_rate_duo(summaries, match_level_available:)
      summaries
        .select { |summary| eligible_for_win_rate_duo?(summary, match_level_available:) }
        .sort_by { |summary| [ -summary.win_rate.to_i, -summary.wins.to_i, -play_count_for(summary, match_level_available:), -summary.offense_total, summary.player_a.name, summary.player_b.name ] }
        .first
    end

    def best_offensive_duo(summaries, match_level_available:)
      summaries
        .select { |summary| eligible_for_offensive_duo?(summary, match_level_available:) }
        .sort_by { |summary| [ -summary.direct_offense_total, -summary.mutual_assists.to_i, -summary.offense_total, -summary.win_rate.to_i, -play_count_for(summary, match_level_available:), summary.player_a.name, summary.player_b.name ] }
        .first
    end

    def ranked_summaries(summaries, match_level_available:)
      summaries.sort_by do |summary|
        [
          -play_count_for(summary, match_level_available:),
          -summary.win_rate.to_i,
          -summary.offense_total,
          summary.player_a.name,
          summary.player_b.name
        ]
      end
    end

    def eligible_for_balanced_duo?(summary, match_level_available:)
      return summary.shared_matches_count >= 3 if summary.match_level?
      return false if match_level_available

      summary.shared_match_days_count >= 2
    end

    def eligible_for_win_rate_duo?(summary, match_level_available:)
      return summary.shared_matches_count >= 5 if summary.match_level?
      return false if match_level_available

      summary.shared_match_days_count >= 3
    end

    def eligible_for_offensive_duo?(summary, match_level_available:)
      return false unless summary.direct_offense_total.positive?

      return summary.shared_matches_count >= 3 if summary.match_level?
      return false if match_level_available

      summary.shared_match_days_count >= 2
    end

    def play_count_for(summary, match_level_available:)
      return summary.shared_matches_count.to_i if match_level_available

      summary.shared_count
    end
  end
end
