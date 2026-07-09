module Synergy
  class CombinationRankingQuery
    Result = Struct.new(
      :players,
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
      def win_rate
        return nil if shared_matches_count.to_i.zero?

        ((wins.to_f / shared_matches_count) * 100).round
      end

      def goals_assists
        goals.to_i + assists.to_i
      end
    end

    VALID_DIRECTIONS = %w[best worst].freeze
    VALID_LIMITS = [ 20, 50 ].freeze
    VALID_COMBINATION_SIZES = (2..5).freeze

    def self.call(season: nil, combination_size: 2, direction: "best", limit: 20, minimum_shared_matches: 3, player_filter: nil, player_id: nil)
      new(season:, combination_size:, direction:, limit:, minimum_shared_matches:, player_filter:, player_id:).call
    end

    def initialize(season:, combination_size:, direction:, limit:, minimum_shared_matches:, player_filter:, player_id: nil)
      @season = season
      @combination_size = normalize_combination_size(combination_size)
      @direction = VALID_DIRECTIONS.include?(direction.to_s) ? direction.to_s : "best"
      @limit = VALID_LIMITS.include?(limit.to_i) ? limit.to_i : 20
      @minimum_shared_matches = [ minimum_shared_matches.to_i, 1 ].max
      @player_filter = player_filter.to_s.strip.downcase
      @player_id = player_id.to_i if player_id.present?
      @visible_players = Player.approved.active.index_by(&:id)
    end

    def call
      ranked_results.first(limit)
    end

    private

    attr_reader :season, :combination_size, :direction, :limit, :minimum_shared_matches, :player_filter, :player_id, :visible_players

    def ranked_results
      results = aggregate_combinations.values
        .select { |result| result.shared_matches_count >= minimum_shared_matches }
        .select { |result| player_id_matches?(result) }
        .select { |result| player_filter_matches?(result) }

      results.sort_by { |result| sort_key_for(result) }
    end

    def aggregate_combinations
      finished_matches.each_with_object({}) do |match, combinations|
        aggregate_team_combinations(match:, team: match.home_team, combinations:)
        aggregate_team_combinations(match:, team: match.away_team, combinations:)
      end
    end

    def aggregate_team_combinations(match:, team:, combinations:)
      team_players = visible_team_players(team)
      return if team_players.size < combination_size

      team_players.combination(combination_size) do |combo_team_players|
        player_ids = combo_team_players.map(&:player_id).sort
        result = combinations[player_ids] ||= build_result(player_ids)

        result.shared_matches_count += 1
        result.goals += goals_for_combo(match:, team:, player_ids:)
        result.assists += assists_for_combo(match:, team:, player_ids:)
        result.mutual_assists += mutual_assists_for_combo(match:, team:, player_ids:)
        result.goal_difference += goal_difference_for(match:, team:)
        update_record(result:, match:, team:)
      end
    end

    def finished_matches
      scope = Match
        .where(status: Match::STATUS_FINISHED)
        .includes(
          home_team: { team_players: :player },
          away_team: { team_players: :player },
          active_match_goals: [ { scorer_team_player: :player }, { assistant_team_player: :player } ]
        )
      scope = scope.joins(:match_day).where(match_days: { season_id: season.id }) if season.present?

      scope
    end

    def visible_team_players(team)
      team.team_players.select { |team_player| visible_players.key?(team_player.player_id) }
    end

    def build_result(player_ids)
      Result.new(
        players: player_ids.filter_map { |player_id| visible_players[player_id] },
        shared_matches_count: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goals: 0,
        assists: 0,
        mutual_assists: 0,
        goal_difference: 0
      )
    end

    def update_record(result:, match:, team:)
      if match.draw?
        result.draws += 1
      elsif match.winner == team
        result.wins += 1
      else
        result.losses += 1
      end
    end

    def goals_for_combo(match:, team:, player_ids:)
      match.active_match_goals.count do |goal|
        goal.scoring_team_id == team.id && player_ids.include?(goal.scorer_team_player.player_id)
      end
    end

    def assists_for_combo(match:, team:, player_ids:)
      match.active_match_goals.count do |goal|
        goal.scoring_team_id == team.id && goal.assistant_team_player.present? && player_ids.include?(goal.assistant_team_player.player_id)
      end
    end

    def mutual_assists_for_combo(match:, team:, player_ids:)
      match.active_match_goals.count do |goal|
        goal.scoring_team_id == team.id &&
          goal.assistant_team_player.present? &&
          player_ids.include?(goal.scorer_team_player.player_id) &&
          player_ids.include?(goal.assistant_team_player.player_id)
      end
    end

    def goal_difference_for(match:, team:)
      if match.home_team_id == team.id
        match.home_score - match.away_score
      else
        match.away_score - match.home_score
      end
    end

    def player_filter_matches?(result)
      return true if player_filter.blank?

      result.players.any? do |player|
        player.name.downcase.include?(player_filter) || player.nickname.to_s.downcase.include?(player_filter)
      end
    end

    def player_id_matches?(result)
      return true if player_id.blank?

      result.players.any? { |player| player.id == player_id }
    end

    def sort_key_for(result)
      if direction == "worst"
        [ result.win_rate.to_i, -result.losses, -result.shared_matches_count, result.goals_assists, player_names_for(result) ]
      else
        [ -result.win_rate.to_i, -result.wins, -result.shared_matches_count, -result.goals_assists, player_names_for(result) ]
      end
    end

    def player_names_for(result)
      result.players.map(&:name).join(" ")
    end

    def normalize_combination_size(value)
      size = value.to_i
      VALID_COMBINATION_SIZES.include?(size) ? size : 2
    end
  end
end
