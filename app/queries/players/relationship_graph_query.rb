module Players
  class RelationshipGraphQuery
    Node = Struct.new(:player, :top_teammates, keyword_init: true)
    Result = Struct.new(:players, :edges, :nodes, keyword_init: true)

    def self.call(players: Player.approved.active.order(:name))
      new(players:).call
    end

    def initialize(players:)
      @players = players.to_a
    end

    def call
      edges = visible_edges

      Result.new(
        players: players,
        edges: edges,
        nodes: players.map { |player| Node.new(player: player, top_teammates: top_teammates_for(player:, edges: edges)) }
      )
    end

    private

    attr_reader :players

    def visible_edges
      visible_player_ids = players.map(&:id)

      Players::BestDuoLeaderboardQuery.call.select do |edge|
        visible_player_ids.include?(edge.player_one.id) && visible_player_ids.include?(edge.player_two.id)
      end
    end

    def top_teammates_for(player:, edges:)
      connected_edges = edges.select { |edge| edge.player_one.id == player.id || edge.player_two.id == player.id }
      return [] if connected_edges.empty?

      highest_shared_match_days_count = connected_edges.map(&:shared_match_days_count).max

      connected_edges
        .select { |edge| edge.shared_match_days_count == highest_shared_match_days_count }
        .map { |edge| edge.player_one.id == player.id ? edge.player_two : edge.player_one }
        .sort_by(&:name)
    end
  end
end
