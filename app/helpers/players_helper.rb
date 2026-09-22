module PlayersHelper
  PLAYER_PROFILE_SYNERGY_SORT_COLUMNS = %w[
    partner shared_matches wins draws losses win_rate goals assists mutual_assists goals_assists
  ].freeze
  PLAYER_PROFILE_OPPONENT_SORT_COLUMNS = %w[
    opponent matches wins draws losses win_rate loss_rate player_goals player_assists opponent_goals
    opponent_assists team_goals_for team_goals_against
  ].freeze

  PLAYER_PROFILE_TABS = {
    "overview" => "layout-dashboard",
    "stats" => "chart-no-axes-combined",
    "matches" => "list-checks",
    "charts" => "chart-line",
    "elo" => "trending-up",
    "synergy" => "network",
    "opponents" => "swords",
    "awards" => "award"
  }.freeze

  def player_profile_tabs
    PLAYER_PROFILE_TABS
  end

  def player_directory_initials(player)
    player.name.split.map { |part| part.first }.join.first(2).upcase
  end

  def player_directory_elo(card)
    card.season_stat&.elo || card.player.elo || "—"
  end

  def player_directory_last_played(card)
    return t("players.directory.no_matches_short") if card.last_played_on.blank?

    l(card.last_played_on)
  end

  def player_directory_record(card)
    [ card.wins, card.draws, card.losses ].join("-")
  end

  def player_profile_initials(player)
    player_directory_initials(player)
  end

  def player_profile_tab_path(player, profile, tab)
    player_path(player, season_id: profile.season&.id, tab:)
  end

  def player_profile_result_label(result)
    case result
    when Team::RESULT_WIN then "W"
    when Team::RESULT_DRAW then "R"
    when Team::RESULT_LOSS then "P"
    else "—"
    end
  end

  def player_profile_signed_delta(value)
    return "—" if value.blank?

    value.to_i.positive? ? "+#{value.to_i}" : value.to_i.to_s
  end

  def player_profile_rate(value)
    number_with_precision(value.to_d, precision: 2, strip_insignificant_zeros: true)
  end

  def player_profile_partner(result, player)
    result.players.find { |partner| partner.id != player.id }
  end

  def player_profile_synergy_sorted_entries(entries, player:, sort_column:, sort_direction:)
    column = player_profile_synergy_sort_column(sort_column)
    direction = player_profile_synergy_sort_direction(sort_direction)
    return entries if column.blank? || direction.blank?

    entries.sort do |left, right|
      left_value = player_profile_synergy_sort_value(left, player, column)
      right_value = player_profile_synergy_sort_value(right, player, column)
      comparison = left_value <=> right_value

      if comparison.zero?
        left_partner_name = player_profile_partner(left, player).name.to_s.downcase
        right_partner_name = player_profile_partner(right, player).name.to_s.downcase

        left_partner_name <=> right_partner_name
      else
        direction == "desc" ? -comparison : comparison
      end
    end
  end

  def player_profile_synergy_sort_link(player:, profile:, column:, sort_column:, sort_direction:)
    next_direction = player_profile_synergy_next_sort_direction(column, sort_column, sort_direction)
    label = capture { yield }
    path = player_path(
      player,
      season_id: profile.season&.id,
      tab: "synergy",
      sort: column,
      sort_direction: next_direction
    )

    link_to path,
            class: "leaderboards-sort-link",
            data: { turbo_frame: "player_profile_synergy_results" },
            aria: { label: strip_tags(label).squish } do
      safe_join([ label, player_profile_synergy_sort_indicator(column, sort_column, sort_direction) ].compact)
    end
  end

  def player_profile_synergy_sort_aria(column, sort_column, sort_direction)
    return "none" unless player_profile_synergy_sort_column(sort_column) == column.to_s

    direction = player_profile_synergy_sort_direction(sort_direction)
    return "none" if direction.blank?

    direction == "asc" ? "ascending" : "descending"
  end

  def player_profile_opponents_sorted_entries(entries, sort_column:, sort_direction:)
    column = player_profile_opponents_sort_column(sort_column)
    direction = player_profile_synergy_sort_direction(sort_direction)
    return entries if column.blank? || direction.blank?

    entries.sort do |left, right|
      comparison = player_profile_opponents_sort_value(left, column) <=> player_profile_opponents_sort_value(right, column)

      if comparison.zero?
        player_profile_opponents_tie_breaker(left, right, column)
      else
        direction == "desc" ? -comparison : comparison
      end
    end
  end

  def player_profile_opponents_sort_link(player:, profile:, column:, sort_column:, sort_direction:, attendance_percent:)
    next_direction = player_profile_opponents_next_sort_direction(column, sort_column, sort_direction)
    label = capture { yield }
    path = player_path(
      player,
      season_id: profile.season&.id,
      tab: "opponents",
      sort: column,
      sort_direction: next_direction,
      attendance_percent:
    )

    link_to path,
            class: "leaderboards-sort-link",
            data: { turbo_frame: "player_profile_opponents_results" },
            aria: { label: strip_tags(label).squish } do
      safe_join([ label, player_profile_opponents_sort_indicator(column, sort_column, sort_direction) ].compact)
    end
  end

  def player_profile_opponents_sort_aria(column, sort_column, sort_direction)
    return "none" unless player_profile_opponents_sort_column(sort_column) == column.to_s

    direction = player_profile_synergy_sort_direction(sort_direction)
    return "none" if direction.blank?

    direction == "asc" ? "ascending" : "descending"
  end

  def player_profile_opponent_rate(value)
    number_with_precision(value.to_d, precision: 1, strip_insignificant_zeros: true)
  end

  def player_profile_opponents_attendance_percent(value)
    Seasons::PublicLeaderboardQuery.normalize_attendance_percent(value)
  end

  def player_profile_opponents_minimum_matches(total_matches:, attendance_percent:)
    (total_matches.to_i * attendance_percent.to_i / 100.0).floor
  end

  def player_profile_opponents_filtered_entries(entries, minimum_matches:)
    entries.select { |entry| entry.matches_count.to_i >= minimum_matches.to_i }
  end

  def player_profile_duo_names(result)
    result.players.map { |partner| link_to(partner.name, player_path(partner)) }.then { |links| safe_join(links, tag.span(" + ", class: "relationship-duo-card__plus")) }
  end

  def player_profile_chart_data(data)
    json_escape(data.to_json)
  end

  private

  def player_profile_synergy_sort_column(column)
    normalized_column = column.to_s
    PLAYER_PROFILE_SYNERGY_SORT_COLUMNS.include?(normalized_column) ? normalized_column : nil
  end

  def player_profile_opponents_sort_column(column)
    normalized_column = column.to_s
    PLAYER_PROFILE_OPPONENT_SORT_COLUMNS.include?(normalized_column) ? normalized_column : nil
  end

  def player_profile_synergy_sort_direction(direction)
    direction.to_s.in?(%w[asc desc]) ? direction.to_s : nil
  end

  def player_profile_synergy_sort_value(entry, player, column)
    case column
    when "partner"
      player_profile_partner(entry, player).name.to_s.downcase
    when "shared_matches"
      entry.shared_matches_count.to_i
    when "wins"
      entry.wins.to_i
    when "draws"
      entry.draws.to_i
    when "losses"
      entry.losses.to_i
    when "win_rate"
      entry.win_rate.to_f
    when "goals"
      entry.goals.to_i
    when "assists"
      entry.assists.to_i
    when "mutual_assists"
      entry.mutual_assists.to_i
    when "goals_assists"
      entry.goals_assists.to_i
    end
  end

  def player_profile_opponents_sort_value(entry, column)
    case column
    when "opponent" then entry.opponent.name.to_s.downcase
    when "matches" then entry.matches_count.to_i
    when "wins" then entry.wins.to_i
    when "draws" then entry.draws.to_i
    when "losses" then entry.losses.to_i
    when "win_rate" then entry.win_rate.to_f
    when "loss_rate" then entry.loss_rate.to_f
    when "player_goals" then entry.player_goals.to_i
    when "player_assists" then entry.player_assists.to_i
    when "opponent_goals" then entry.opponent_goals.to_i
    when "opponent_assists" then entry.opponent_assists.to_i
    when "team_goals_for" then entry.team_goals_for.to_i
    when "team_goals_against" then entry.team_goals_against.to_i
    end
  end

  def player_profile_opponents_next_sort_direction(column, sort_column, sort_direction)
    return sort_direction.to_s == "asc" ? "desc" : "asc" if sort_column.to_s == column.to_s

    column.to_s == "opponent" ? "asc" : "desc"
  end

  def player_profile_opponents_tie_breaker(left, right, column)
    if column == "losses"
      comparison = right.loss_rate <=> left.loss_rate
      return comparison unless comparison.zero?

      comparison = right.matches_count <=> left.matches_count
      return comparison unless comparison.zero?
    end

    left.opponent.name.to_s.downcase <=> right.opponent.name.to_s.downcase
  end

  def player_profile_synergy_next_sort_direction(column, sort_column, sort_direction)
    return sort_direction.to_s == "asc" ? "desc" : "asc" if sort_column.to_s == column.to_s

    column.to_s == "partner" ? "asc" : "desc"
  end

  def player_profile_synergy_sort_indicator(column, sort_column, sort_direction)
    return if sort_column.to_s != column.to_s || player_profile_synergy_sort_direction(sort_direction).blank?

    indicator = sort_direction.to_s == "asc" ? "↑" : "↓"
    tag.span(indicator, class: "leaderboards-sort-indicator", aria: { hidden: true })
  end

  def player_profile_opponents_sort_indicator(column, sort_column, sort_direction)
    return if sort_column.to_s != column.to_s || player_profile_synergy_sort_direction(sort_direction).blank?

    indicator = sort_direction.to_s == "asc" ? "↑" : "↓"
    tag.span(indicator, class: "leaderboards-sort-indicator", aria: { hidden: true })
  end
end
