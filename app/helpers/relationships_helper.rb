module RelationshipsHelper
  RELATIONSHIP_SORT_COLUMNS = %w[combination matches record win_rate offense mutual_assists].freeze

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

  def relationship_sort_link(column:, label:, sort_column:, sort_direction:, season:, active_tab:, direction:, limit:, metric:, minimum_shared_matches:, player_filter:, player_id:)
    next_direction = relationship_next_sort_direction(column, sort_column, sort_direction)
    path = relationships_path(
      season_id: season&.id,
      tab: active_tab,
      direction:,
      limit:,
      metric:,
      minimum_shared_matches:,
      player_filter: player_filter.presence,
      player_id: player_id.presence,
      sort: column,
      sort_direction: next_direction
    )

    link_to path, class: "leaderboards-sort-link", data: { turbo_frame: "relationships_results" }, aria: { label: } do
      safe_join([ label, relationship_sort_indicator(column, sort_column, sort_direction) ].compact)
    end
  end

  def relationship_sort_aria(column, sort_column, sort_direction)
    return "none" unless relationship_sort_column(sort_column) == column.to_s

    relationship_sort_direction(sort_direction) == "asc" ? "ascending" : "descending"
  end

  private

  def relationship_sort_column(column)
    normalized_column = column.to_s
    RELATIONSHIP_SORT_COLUMNS.include?(normalized_column) ? normalized_column : nil
  end

  def relationship_sort_direction(direction)
    direction.to_s.in?(%w[asc desc]) ? direction.to_s : nil
  end

  def relationship_next_sort_direction(column, sort_column, sort_direction)
    return sort_direction.to_s == "asc" ? "desc" : "asc" if sort_column.to_s == column.to_s

    column.to_s == "combination" ? "asc" : "desc"
  end

  def relationship_sort_indicator(column, sort_column, sort_direction)
    return if sort_column.to_s != column.to_s

    indicator = sort_direction.to_s == "asc" ? "↑" : "↓"

    tag.span(indicator, class: "leaderboards-sort-indicator", aria: { hidden: true })
  end

  def relationship_summary_card(key, summary, primary_metric, icon, fallback, tooltip_key)
    { key:, summary:, primary_metric:, icon:, fallback:, tooltip_key: }
  end
end
