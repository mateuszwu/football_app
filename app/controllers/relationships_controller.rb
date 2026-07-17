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
    "graph" => 1
  }.freeze
  DIRECTIONS = %w[best worst].freeze
  LIMITS = [ 20, 50 ].freeze
  GRAPH_LIMITS = [ 20, 50, 100 ].freeze
  GRAPH_METRICS = %w[shared_matches win_rate goals_assists].freeze

  def index
    season = Season.find_by(id: params[:season_id]) if params[:season_id].present?
    active_tab = normalized_tab
    direction = normalized_direction
    limit = active_tab == "graph" ? normalized_graph_limit : normalized_limit
    metric = normalized_graph_metric
    minimum_shared_matches = normalized_minimum_shared_matches(active_tab)
    player_filter = params[:player_filter].to_s.strip
    player_id = params[:player_id].presence
    selected_player = Player.approved.active.find_by(id: player_id) if player_id.present?
    graph_player_filter = player_filter.presence || selected_player&.name.to_s
    graph = cached_relationship_graph
    duo_insights = cached_duo_insights(season)
    combination_ranking = cached_combination_ranking(
      season:,
      active_tab:,
      direction:,
      limit:,
      minimum_shared_matches:,
      player_filter:,
      player_id:
    )
    graph_data = cached_graph_data(
      season:,
      active_tab:,
      limit:,
      metric:,
      minimum_shared_matches:,
      player_filter:,
      player_id:
    )

    render :index, locals: {
      active_tab:,
      combination_ranking:,
      direction:,
      edges: graph.edges.first(30),
      graph_data:,
      graph_player_filter:,
      limit:,
      metric:,
      minimum_shared_matches:,
      nodes: graph.nodes,
      player_filter:,
      player_id:,
      players: graph.players,
      season:,
      tab_minimums: DEFAULT_MINIMUMS,
      duo_insights:,
      sort_column: params[:sort].to_s.presence,
      sort_direction: params[:sort_direction].to_s.presence
    }
  end

  private

  def cached_relationship_graph
    Rails.cache.fetch([ "relationships-overview", PublicStats::CacheKey.global ], expires_in: 10.minutes) do
      Players::RelationshipGraphQuery.call
    end
  end

  def cached_duo_insights(season)
    Rails.cache.fetch([ "relationships-duo-insights", season&.id || "all", public_cache_key_for(season) ], expires_in: 10.minutes) do
      Relationships::DuoInsightsQuery.call(season:)
    end
  end

  def cached_combination_ranking(season:, active_tab:, direction:, limit:, minimum_shared_matches:, player_filter:, player_id:)
    Rails.cache.fetch([
      "relationships-combination",
      "v3",
      season&.id || "all",
      active_tab,
      direction,
      limit,
      minimum_shared_matches,
      player_filter,
      player_id,
      public_cache_key_for(season)
    ], expires_in: 10.minutes) do
      Synergy::CombinationRankingQuery.call(
        season:,
        combination_size: TAB_SIZES.fetch(active_tab),
        direction:,
        limit:,
        minimum_shared_matches:,
        player_filter:,
        player_id:
      )
    end
  end

  def cached_graph_data(season:, active_tab:, limit:, metric:, minimum_shared_matches:, player_filter:, player_id:)
    graph_limit = active_tab == "graph" ? limit : 20

    Rails.cache.fetch([
      "relationships-graph-data",
      season&.id || "all",
      graph_limit,
      metric,
      minimum_shared_matches,
      player_filter,
      player_id,
      public_cache_key_for(season)
    ], expires_in: 10.minutes) do
      Synergy::GraphDataQuery.call(
        season:,
        minimum_shared_matches:,
        player_filter:,
        player_id:,
        limit: graph_limit,
        metric:
      )
    end
  end

  def public_cache_key_for(season)
    season.present? ? PublicStats::CacheKey.season(season) : PublicStats::CacheKey.global
  end

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
