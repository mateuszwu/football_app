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

      def offensive_stats?
        goals.to_i.positive? || assists.to_i.positive?
      end

      def record?
        shared_matches_count.to_i.positive?
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

      result = Synergy::CombinationRankingQuery.call(
        season:,
        combination_size: 2,
        direction: "best",
        limit: 20,
        minimum_shared_matches: 3
      ).first

      result.present? ? build_summary(result) : empty_summary
    end

    private

    attr_reader :season

    def build_summary(result)
      Summary.new(
        player_a: result.players.first,
        player_b: result.players.second,
        shared_match_days_count: shared_match_days_count_for(result.players),
        shared_matches_count: result.shared_matches_count,
        wins: result.wins,
        draws: result.draws,
        losses: result.losses,
        goals: result.goals,
        assists: result.assists
      )
    end

    def shared_match_days_count_for(players)
      MatchDayPlayer
        .joins(:match_day)
        .where(match_days: { season_id: season.id })
        .where(player_id: players.map(&:id))
        .group(:match_day_id)
        .having("COUNT(DISTINCT match_day_players.player_id) = 2")
        .count
        .size
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
