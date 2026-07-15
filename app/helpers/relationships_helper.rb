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

  def relationship_summary_cards(duo_insights)
    [
      relationship_summary_card(:best_overall_duo, duo_insights.best_overall_duo, :win_rate, "star", "award", :best_overall_duo),
      relationship_summary_card(:most_played_duo, duo_insights.most_played_duo, :shared_count, "users", "link", :most_played_duo),
      relationship_summary_card(:best_win_rate_duo, duo_insights.best_win_rate_duo, :win_rate, "trending-up", "target", :best_win_rate_duo),
      relationship_summary_card(:best_offensive_duo, duo_insights.best_offensive_duo, :direct_offense_total, "zap", "target", :best_offensive_duo)
    ]
  end

  def relationship_tabs(active_tab)
    [
      [ "duos", t("relationships.tabs.duos") ],
      [ "trios", t("relationships.tabs.trios") ],
      [ "fours", t("relationships.tabs.fours") ],
      [ "fives", t("relationships.tabs.fives") ],
      [ "graph", t("relationships.tabs.graph") ]
    ].map do |key, label|
      { key:, label:, active: active_tab == key }
    end
  end

  def relationship_combination_label(active_tab)
    key = {
      "duos" => "duo",
      "trios" => "trio",
      "fours" => "four",
      "fives" => "five",
      "graph" => "duo"
    }.fetch(active_tab, "duo")

    t("relationships.table.#{key}")
  end

  def relationship_win_rate_class(win_rate)
    classes = [ "relationship-win-rate" ]
    return classes.join(" ") if win_rate.nil?

    modifier = win_rate.to_f >= 50 ? "positive" : "negative"
    classes << "relationship-win-rate--#{modifier}"
    classes.join(" ")
  end

  def relationship_ranking_players_count(combination_ranking)
    combination_ranking.flat_map(&:players).uniq(&:id).count
  end

  def relationship_primary_metric(summary, metric)
    case metric
    when :shared_count
      relationship_shared_count_label(summary)
    when :offense_total
      t("relationships.labels.goals_assists_together", value: summary.offense_total)
    when :direct_offense_total
      t("relationships.labels.mutual_assists", count: summary.mutual_assists)
    else
      relationship_win_rate_label(summary) || relationship_shared_count_label(summary)
    end
  end

  def relationship_secondary_metrics(summary, primary_metric)
    primary_is_win_rate = primary_metric == :win_rate && relationship_win_rate_label(summary).present?
    primary_is_shared_count = primary_metric == :shared_count || (primary_metric == :win_rate && !primary_is_win_rate)

    [
      (relationship_win_rate_label(summary) unless primary_is_win_rate),
      (relationship_shared_count_label(summary) unless primary_is_shared_count),
      (t("relationships.labels.goals_assists_together", value: summary.offense_total) if summary.offense_total.positive? && primary_metric != :offense_total),
      (relationship_record_label(summary) if primary_is_win_rate && summary.match_level?),
      (relationship_goals_assists_split_label(summary) if [ :offense_total, :direct_offense_total ].include?(primary_metric) && summary.offense_total.positive?)
    ].compact
  end

  def relationship_shared_count_label(summary)
    key = summary.match_level? ? "shared_matches" : "shared_match_days"
    t("relationships.labels.#{key}", count: summary.shared_count)
  end

  def relationship_win_rate_label(summary)
    return nil if summary.win_rate.blank?

    t("relationships.labels.win_rate", value: summary.win_rate)
  end

  def relationship_record_label(summary)
    t("relationships.labels.record", wins: summary.wins, draws: summary.draws, losses: summary.losses)
  end

  def relationship_goals_assists_split_label(summary)
    t("relationships.labels.goals_assists_split", goals: summary.goals, assists: summary.assists)
  end

  def relationship_table_shared_header(duo_insights)
    if duo_insights.summaries.any?(&:match_level?)
      t("relationships.table.shared_matches")
    else
      t("relationships.table.shared_match_days")
    end
  end

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

  def relationship_summary_card(key, summary, primary_metric, icon, fallback, tooltip_key)
    { key:, summary:, primary_metric:, icon:, fallback:, tooltip_key: }
  end

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
