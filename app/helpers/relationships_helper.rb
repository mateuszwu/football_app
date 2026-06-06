module RelationshipsHelper
  RelationshipGraphLayout = Struct.new(:nodes, :edges, :width, :height, keyword_init: true)
  RelationshipGraphNode = Struct.new(:player, :x, :y, :label_x, :label_y, keyword_init: true)
  RelationshipGraphEdge = Struct.new(
    :player_one,
    :player_two,
    :shared_match_days_count,
    :stroke_width,
    :x1,
    :y1,
    :x2,
    :y2,
    keyword_init: true
  )

  def relationship_graph_layout(players:, edges:, width: 720, height: 480)
    positions = relationship_graph_positions(players:, width:, height:)
    strongest_connection = edges.map(&:shared_match_days_count).max || 1

    RelationshipGraphLayout.new(
      width: width,
      height: height,
      nodes: players.map do |player|
        position = positions.fetch(player.id)

        RelationshipGraphNode.new(
          player: player,
          x: position[:x],
          y: position[:y],
          label_x: position[:x],
          label_y: position[:y] + 34
        )
      end,
      edges: edges.map do |edge|
        player_one_position = positions.fetch(edge.player_one.id)
        player_two_position = positions.fetch(edge.player_two.id)

        RelationshipGraphEdge.new(
          player_one: edge.player_one,
          player_two: edge.player_two,
          shared_match_days_count: edge.shared_match_days_count,
          stroke_width: relationship_graph_stroke_width(
            shared_match_days_count: edge.shared_match_days_count,
            strongest_connection: strongest_connection
          ),
          x1: player_one_position[:x],
          y1: player_one_position[:y],
          x2: player_two_position[:x],
          y2: player_two_position[:y]
        )
      end
    )
  end

  private

  def relationship_graph_positions(players:, width:, height:)
    return {} if players.empty?
    return { players.first.id => { x: width / 2, y: height / 2 } } if players.one?

    center_x = width / 2.0
    center_y = height / 2.0
    radius = [ [ width, height ].min / 2.0 - 72, 80 ].max

    players.each_with_index.to_h do |player, index|
      angle = (2 * Math::PI * index) / players.count - (Math::PI / 2)

      [
        player.id,
        {
          x: (center_x + radius * Math.cos(angle)).round(1),
          y: (center_y + radius * Math.sin(angle)).round(1)
        }
      ]
    end
  end

  def relationship_graph_stroke_width(shared_match_days_count:, strongest_connection:)
    return 3.0 if strongest_connection <= 1

    2.0 + ((shared_match_days_count - 1).to_f / (strongest_connection - 1) * 4.0)
  end
end
