module Synergy
  class GraphDataQuery
    EdgeResult = Struct.new(
      :players,
      :shared_matches,
      :wins,
      :draws,
      :losses,
      :goals,
      :assists,
      keyword_init: true
    ) do
      def win_rate
        return nil if shared_matches.to_i.zero?

        ((wins.to_f / shared_matches) * 100).round
      end

      def goals_assists
        goals.to_i + assists.to_i
      end

      def label
        players.map(&:name).join(" + ")
      end
    end

    METRICS = %w[shared_matches win_rate goals_assists].freeze
    LIMITS = [ 20, 50, 100 ].freeze
    MIN_EDGE_WIDTH = 1
    MAX_EDGE_WIDTH = 10

    def self.call(season: nil, minimum_shared_matches: 1, player_filter: nil, player_id: nil, limit: 50, metric: "shared_matches")
      new(season:, minimum_shared_matches:, player_filter:, player_id:, limit:, metric:).call
    end

    def initialize(season:, minimum_shared_matches:, player_filter:, limit:, metric:, player_id: nil)
      @season = season
      @minimum_shared_matches = [ minimum_shared_matches.to_i, 1 ].max
      @player_filter = player_filter.to_s.strip.downcase
      @player_id = player_id.to_i if player_id.present?
      @limit = LIMITS.include?(limit.to_i) ? limit.to_i : 50
      @metric = METRICS.include?(metric.to_s) ? metric.to_s : "shared_matches"
      @visible_players = Player.approved.active.index_by(&:id)
    end

    def call
      visible_edges = ranked_edges
      visible_players = players_for(visible_edges)

      {
        elements: node_elements_for(visible_players, visible_edges) + edge_elements_for(visible_edges),
        meta: {
          players_count: visible_players.count,
          edges_count: visible_edges.count,
          minimum_shared_matches: minimum_shared_matches,
          limit: limit,
          metric: metric
        },
        top_connections: visible_edges.first(5).map { |edge| top_connection_for(edge) }
      }
    end

    private

    attr_reader :season, :minimum_shared_matches, :player_filter, :player_id, :limit, :metric, :visible_players

    def ranked_edges
      edges = aggregate_edges.values
        .select { |edge| edge.shared_matches >= minimum_shared_matches }
        .select { |edge| player_id_matches?(edge) }
        .select { |edge| player_filter_matches?(edge) }

      edges.sort_by { |edge| sort_key_for(edge) }.first(limit)
    end

    def aggregate_edges
      finished_matches.each_with_object({}) do |match, edges|
        aggregate_team_edges(match:, team: match.home_team, edges:)
        aggregate_team_edges(match:, team: match.away_team, edges:)
      end
    end

    def aggregate_team_edges(match:, team:, edges:)
      team_players = visible_team_players(team)
      return if team_players.size < 2

      team_players.combination(2) do |pair_team_players|
        player_ids = pair_team_players.map(&:player_id).sort
        edge = edges[player_ids] ||= build_edge(player_ids)

        edge.shared_matches += 1
        edge.goals += goals_for_pair(match:, team:, player_ids:)
        edge.assists += assists_for_pair(match:, team:, player_ids:)
        update_record(edge:, match:, team:)
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

    def build_edge(player_ids)
      EdgeResult.new(
        players: player_ids.filter_map { |player_id| visible_players[player_id] },
        shared_matches: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goals: 0,
        assists: 0
      )
    end

    def update_record(edge:, match:, team:)
      if match.draw?
        edge.draws += 1
      elsif match.winner == team
        edge.wins += 1
      else
        edge.losses += 1
      end
    end

    def goals_for_pair(match:, team:, player_ids:)
      match.active_match_goals.count do |goal|
        goal.scoring_team_id == team.id && player_ids.include?(goal.scorer_team_player.player_id)
      end
    end

    def assists_for_pair(match:, team:, player_ids:)
      match.active_match_goals.count do |goal|
        goal.scoring_team_id == team.id && goal.assistant_team_player.present? && player_ids.include?(goal.assistant_team_player.player_id)
      end
    end

    def player_filter_matches?(edge)
      return true if player_filter.blank?

      edge.players.any? do |player|
        player.name.downcase.include?(player_filter) || player.nickname.to_s.downcase.include?(player_filter)
      end
    end

    def player_id_matches?(edge)
      return true if player_id.blank?

      edge.players.any? { |player| player.id == player_id }
    end

    def sort_key_for(edge)
      case metric
      when "win_rate"
        [ -edge.win_rate.to_i, -edge.wins, -edge.shared_matches, edge.label ]
      when "goals_assists"
        [ -edge.goals_assists, -edge.goals, -edge.assists, -edge.shared_matches, edge.label ]
      else
        [ -edge.shared_matches, -edge.goals_assists, -edge.win_rate.to_i, edge.label ]
      end
    end

    def players_for(edges)
      edges.flat_map(&:players).uniq(&:id).sort_by(&:name)
    end

    def node_elements_for(players, edges)
      degrees = degree_counts_for(edges)

      players.map do |player|
        {
          data: {
            id: player_id_for(player),
            player_id: player.id,
            label: initials_for(player),
            name: player.name,
            role: player.role_code,
            profile_path: "/players/#{player.id}",
            degree: degrees.fetch(player.id, 0)
          }
        }
      end
    end

    def edge_elements_for(edges)
      edges.map do |edge|
        first_player, second_player = edge.players

        {
          data: {
            id: "edge-#{first_player.id}-#{second_player.id}",
            source: player_id_for(first_player),
            target: player_id_for(second_player),
            label: edge.label,
            shared_matches: edge.shared_matches,
            wins: edge.wins,
            draws: edge.draws,
            losses: edge.losses,
            win_rate: edge.win_rate,
            goals: edge.goals,
            assists: edge.assists,
            goals_assists: edge.goals_assists,
            width: edge_width_for(edge.shared_matches),
            color_group: color_group_for(edge.win_rate)
          }
        }
      end
    end

    def top_connection_for(edge)
      {
        label: edge.label,
        shared_matches: edge.shared_matches,
        wins: edge.wins,
        draws: edge.draws,
        losses: edge.losses,
        win_rate: edge.win_rate,
        goals: edge.goals,
        assists: edge.assists,
        goals_assists: edge.goals_assists
      }
    end

    def degree_counts_for(edges)
      edges.each_with_object(Hash.new(0)) do |edge, degrees|
        edge.players.each { |player| degrees[player.id] += 1 }
      end
    end

    def edge_width_for(shared_matches)
      shared_matches.to_i.clamp(MIN_EDGE_WIDTH, MAX_EDGE_WIDTH)
    end

    def color_group_for(win_rate)
      return "hidden" if win_rate.blank?
      return "high" if win_rate >= 70
      return "medium" if win_rate >= 50

      "low"
    end

    def player_id_for(player)
      "player-#{player.id}"
    end

    def initials_for(player)
      player.name.split.map { |part| part.first.upcase }.first(2).join
    end
  end
end
