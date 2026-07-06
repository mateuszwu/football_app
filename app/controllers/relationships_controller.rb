class RelationshipsController < ApplicationController
  TAB_SIZES = {
    "duos" => 2,
    "trios" => 3,
    "fours" => 4,
    "fives" => 5,
    "graph" => 2
  }.freeze
  DEFAULT_MINIMUMS = {
    "duos" => 3,
    "trios" => 3,
    "fours" => 2,
    "fives" => 2,
    "graph" => 3
  }.freeze
  DIRECTIONS = %w[best worst].freeze
  LIMITS = [ 20, 50 ].freeze
  GRAPH_LIMITS = [ 20, 50, 100 ].freeze
  GRAPH_METRICS = %w[shared_matches win_rate goals_assists].freeze

  def index
    season = Season.find_by(id: params[:season_id]) if params[:season_id].present?
    graph = Players::RelationshipGraphQuery.call
    duo_insights = Relationships::DuoInsightsQuery.call
    active_tab = normalized_tab
    direction = normalized_direction
    limit = active_tab == "graph" ? normalized_graph_limit : normalized_limit
    metric = normalized_graph_metric
    minimum_shared_matches = normalized_minimum_shared_matches(active_tab)
    player_filter = params[:player_filter].to_s.strip
    player_id = params[:player_id].presence
    combination_ranking = Synergy::CombinationRankingQuery.call(
      season:,
      combination_size: TAB_SIZES.fetch(active_tab),
      direction:,
      limit:,
      minimum_shared_matches:,
      player_filter:,
      player_id:
    )
    graph_data = Synergy::GraphDataQuery.call(
      season:,
      minimum_shared_matches:,
      player_filter:,
      player_id:,
      limit: active_tab == "graph" ? limit : 20,
      metric:
    )

    render :index, locals: {
      active_tab:,
      combination_ranking:,
      direction:,
      edges: graph.edges.first(30),
      graph_data:,
      limit:,
      metric:,
      minimum_shared_matches:,
      nodes: graph.nodes,
      player_filter:,
      player_id:,
      players: graph.players,
      season:,
      tab_minimums: DEFAULT_MINIMUMS,
      duo_insights:
    }
  end

  private

  def normalized_tab
    TAB_SIZES.key?(params[:tab].to_s) ? params[:tab].to_s : "duos"
  end

  def normalized_direction
    DIRECTIONS.include?(params[:direction].to_s) ? params[:direction].to_s : "best"
  end

  def normalized_limit
    LIMITS.include?(params[:limit].to_i) ? params[:limit].to_i : 20
  end

  def normalized_graph_limit
    GRAPH_LIMITS.include?(params[:limit].to_i) ? params[:limit].to_i : 50
  end

  def normalized_graph_metric
    GRAPH_METRICS.include?(params[:metric].to_s) ? params[:metric].to_s : "shared_matches"
  end

  def normalized_minimum_shared_matches(active_tab)
    minimum = params[:minimum_shared_matches].presence || DEFAULT_MINIMUMS.fetch(active_tab)

    [ minimum.to_i, 1 ].max
  end
end
