module Relationships
  class PairStatsQuery
    Result = Struct.new(
      :player_one,
      :player_two,
      :shared_match_days_count,
      :shared_matches_count,
      :wins,
      :draws,
      :losses,
      :goals,
      :assists,
      :mutual_assists,
      :goal_difference,
      keyword_init: true
    ) do
      def players
        [ player_one, player_two ]
      end

      def goals_assists
        goals.to_i + assists.to_i
      end
    end

    SUMMED_COLUMNS = %i[
      shared_match_days_count
      shared_matches_count
      wins
      draws
      losses
      goals
      assists
      mutual_assists
      goal_difference
    ].freeze

    def self.call(season: nil, players: Player.approved.active)
      new(season:, players:).call
    end

    def initialize(season:, players:)
      @season = season
      @players = players.to_a
    end

    def call
      ensure_generated

      aggregated_rows.filter_map do |row|
        player_one = players_by_id[row[0]]
        player_two = players_by_id[row[1]]
        next if player_one.blank? || player_two.blank?

        Result.new(
          player_one:,
          player_two:,
          **SUMMED_COLUMNS.zip(row.drop(2).map(&:to_i)).to_h
        )
      end
    end

    private

    attr_reader :players, :season

    def ensure_generated
      seasons_to_generate.find_each do |candidate|
        Relationships::RebuildSeasonPairStats.call(season: candidate)
      end
    end

    def seasons_to_generate
      scope = Season.where(pair_stats_generated_at: nil)
      season.present? ? scope.where(id: season.id) : scope
    end

    def aggregated_rows
      scope = SeasonPairStat.all
      scope = scope.where(season:) if season.present?

      scope
        .group(:player_one_id, :player_two_id)
        .pluck(
          :player_one_id,
          :player_two_id,
          *SUMMED_COLUMNS.map { |column| Arel.sql("SUM(season_pair_stats.#{column})") }
        )
    end

    def players_by_id
      @players_by_id ||= players.index_by(&:id)
    end
  end
end
