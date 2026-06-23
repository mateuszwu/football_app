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

      summaries.sort_by do |summary|
        [
          -summary.shared_match_days_count,
          -summary.wins,
          -summary.offense_total,
          summary.player_a.name,
          summary.player_b.name
        ]
      end.first || empty_summary
    end

    private

    attr_reader :season

    def summaries
      Players::BestDuoLeaderboardQuery.call(season:).map do |duo|
        build_summary(duo)
      end
    end

    def build_summary(duo)
      shared_matches = shared_matches_for(duo)
      goals, assists = offensive_totals_for(duo:, shared_matches:)
      wins, draws, losses = record_for(shared_matches)

      Summary.new(
        player_a: duo.player_one,
        player_b: duo.player_two,
        shared_match_days_count: duo.shared_match_days_count,
        shared_matches_count: shared_matches.count,
        wins: wins,
        draws: draws,
        losses: losses,
        goals: goals,
        assists: assists
      )
    end

    def shared_matches_for(duo)
      shared_team_ids = shared_team_ids_for(duo)
      return [] if shared_team_ids.empty?

      Match
        .where(match_day: season.match_days)
        .where(status: Match::STATUS_FINISHED)
        .where("home_team_id IN (:team_ids) OR away_team_id IN (:team_ids)", team_ids: shared_team_ids)
        .includes(:home_team, :away_team)
        .filter_map { |match| shared_match_for(match:, shared_team_ids:) }
    end

    def shared_team_ids_for(duo)
      Team
        .joins(:team_players)
        .joins(team_setup: :match_day)
        .where(team_type: Team::TEAM_TYPE_MATCH)
        .where(match_days: { season_id: season.id })
        .where(team_players: { player_id: [ duo.player_one.id, duo.player_two.id ] })
        .group("teams.id")
        .having("COUNT(DISTINCT team_players.player_id) = 2")
        .pluck(:id)
    end

    def shared_match_for(match:, shared_team_ids:)
      shared_team = if shared_team_ids.include?(match.home_team_id)
        match.home_team
      elsif shared_team_ids.include?(match.away_team_id)
        match.away_team
      end

      return nil if shared_team.blank?

      [ match, shared_team ]
    end

    def record_for(shared_matches)
      shared_matches.each_with_object([ 0, 0, 0 ]) do |(match, shared_team), record|
        if match.draw?
          record[1] += 1
        elsif match.winner == shared_team
          record[0] += 1
        else
          record[2] += 1
        end
      end
    end

    def offensive_totals_for(duo:, shared_matches:)
      match_ids = shared_matches.map { |match, _team| match.id }
      return [ 0, 0 ] if match_ids.empty?

      player_ids = [ duo.player_one.id, duo.player_two.id ]
      goals = MatchGoal
        .active
        .joins(:scorer_team_player)
        .where(match_id: match_ids)
        .where(team_players: { player_id: player_ids })
        .count
      assists = MatchGoal
        .active
        .joins(:assistant_team_player)
        .where(match_id: match_ids)
        .where(team_players: { player_id: player_ids })
        .count

      [ goals, assists ]
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
