module Relationships
  class BestDuoSummary
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

      def offensive_stats?
        goals.to_i.positive? || assists.to_i.positive?
      end

      def record?
        match_level?
      end

      def win_rate
        return nil unless record?

        ((wins.to_f / shared_matches_count) * 100).round
      end

      def offense_total
        goals.to_i + assists.to_i
      end
    end

    def self.call(season:)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      return empty_summary if season.blank?

      result = DuoInsightsQuery.call(season:).best_overall_duo

      result.present? ? build_summary(result) : empty_summary
    end

    private

    attr_reader :season

    def build_summary(result)
      Summary.new(
        player_a: result.player_a,
        player_b: result.player_b,
        shared_match_days_count: result.shared_match_days_count,
        shared_matches_count: result.shared_matches_count,
        wins: result.wins,
        draws: result.draws,
        losses: result.losses,
        goals: result.goals,
        assists: result.assists
      )
    end

    def empty_summary
      Summary.new(
        player_a: nil,
        player_b: nil,
        shared_match_days_count: 0,
        shared_matches_count: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goals: 0,
        assists: 0
      )
    end
  end
end
