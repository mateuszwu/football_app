class RelationshipsController < ApplicationController
  def index
    graph = Players::RelationshipGraphQuery.call

    render :index, locals: {
      edges: graph.edges,
      nodes: graph.nodes,
      players: graph.players,
      strongest_edge: graph.edges.first
    }
  end
end
