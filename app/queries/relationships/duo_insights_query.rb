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

      def duet_score
        wins.to_i * 3 + draws.to_i + offense_total
      end
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
      visible_player_ids = players.map(&:id)

      Players::BestDuoLeaderboardQuery.call(season:)
        .select { |duo| visible_player_ids.include?(duo.player_one.id) && visible_player_ids.include?(duo.player_two.id) }
        .map { |duo| build_summary(duo) }
    end

    def build_summary(duo)
      shared_matches = shared_matches_for(duo)
      goals, assists = offensive_totals_for(duo:, shared_matches:)
      mutual_assists = mutual_assists_for(duo:, shared_matches:)
      wins, draws, losses = record_for(shared_matches)

      Summary.new(
        player_a: duo.player_one,
        player_b: duo.player_two,
        shared_match_days_count: duo.shared_match_days_count,
        shared_matches_count: shared_matches.count,
        wins:,
        draws:,
        losses:,
        goals:,
        assists:,
        mutual_assists:
      )
    end

    def best_overall_duo(summaries, match_level_available:)
      summaries
        .select { |summary| eligible_for_balanced_duo?(summary, match_level_available:) }
        .sort_by { |summary| [ -summary.duet_score, -play_count_for(summary, match_level_available:), summary.player_a.name, summary.player_b.name ] }
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

    def shared_matches_for(duo)
      shared_team_ids = shared_team_ids_for(duo)
      return [] if shared_team_ids.empty?

      scope = Match
        .where(status: Match::STATUS_FINISHED)
        .where("home_team_id IN (:team_ids) OR away_team_id IN (:team_ids)", team_ids: shared_team_ids)
        .includes(:home_team, :away_team)
      scope = scope.joins(:match_day).where(match_days: { season_id: season.id }) if season.present?

      scope.filter_map { |match| shared_match_for(match:, shared_team_ids:) }
    end

    def shared_team_ids_for(duo)
      scope = Team
        .joins(:team_players)
        .joins(team_setup: :match_day)
        .where(team_type: Team::TEAM_TYPE_MATCH)
        .where(team_players: { player_id: [ duo.player_one.id, duo.player_two.id ] })
        .group("teams.id")
        .having("COUNT(DISTINCT team_players.player_id) = 2")
      scope = scope.where(match_days: { season_id: season.id }) if season.present?

      scope.pluck(:id)
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

    def mutual_assists_for(duo:, shared_matches:)
      match_ids = shared_matches.map { |match, _team| match.id }
      return 0 if match_ids.empty?

      player_ids = [ duo.player_one.id, duo.player_two.id ]

      MatchGoal
        .active
        .includes(:scorer_team_player, :assistant_team_player)
        .where(match_id: match_ids)
        .to_a
        .count do |goal|
          goal.assistant_team_player.present? &&
            player_ids.include?(goal.scorer_team_player.player_id) &&
            player_ids.include?(goal.assistant_team_player.player_id)
        end
    end
  end
end
