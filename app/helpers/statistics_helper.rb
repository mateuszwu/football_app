module StatisticsHelper
  STATISTICS_SORT_COLUMNS = {
    "tempo" => %i[record match_or_player value],
    "first_goal" => %i[player first_goals matches first_goal_rate win_rate_after_first_goal],
    "comebacks" => %i[deficit situations comeback_wins comeback_rate example_match],
    "score_states" => %i[state occurrences leader_wins hold_rate comeback_count],
    "records" => %i[record match_or_player value],
    "clutch" => %i[player opening_goals closing_goals go_ahead_goals equalizer_goals goals_when_tied comeback_contribution]
  }.freeze

  def statistics_tabs
    Stats::SeasonInsightsQuery::TABS
  end

  def statistics_sorted_rows(rows, tab:, sort_column:, sort_direction:)
    column = statistics_sort_column(tab, sort_column)
    direction = statistics_sort_direction(sort_direction)
    return rows if column.blank? || direction.blank?

    sorted_rows = rows.sort_by { |row| statistics_sort_value(row, tab, column) }
    sorted_rows.reverse! if direction == "desc"
    sorted_rows
  end

  def statistics_sort_link(season:, tab:, column:, sort_column:, sort_direction:)
    next_direction = statistics_next_sort_direction(column, sort_column, sort_direction)
    path = statistics_path(
      season_id: season.id,
      tab:,
      sort: column,
      sort_direction: next_direction
    )
    label = capture { yield }

    link_to path, class: "leaderboards-sort-link", aria: { label: strip_tags(label).squish } do
      safe_join([ label, statistics_sort_indicator(column, sort_column, sort_direction) ].compact)
    end
  end

  def statistics_sort_aria(tab, column, sort_column, sort_direction)
    direction = statistics_sort_direction(sort_direction)
    return "none" unless direction.present? && statistics_sort_column(tab, sort_column) == column.to_sym

    direction == "asc" ? "ascending" : "descending"
  end

  def statistics_format_duration(seconds)
    return "-" if seconds.blank?

    minutes = seconds.to_i / 60
    remaining_seconds = seconds.to_i % 60
    format("%<minutes>02d:%<seconds>02d", minutes:, seconds: remaining_seconds)
  end

  def statistics_format_percentage(value)
    "#{value.to_i}%"
  end

  def statistics_card_value(card)
    card&.fetch(:value).presence || t("statistics.index.empty.no_time_data")
  end

  def statistics_card_subject(card)
    card&.fetch(:subject).presence || t("statistics.index.empty.no_timeline_body")
  end

  def statistics_card_detail(card)
    card&.fetch(:detail).presence || ""
  end

  def statistics_row_value(value)
    value.presence || "-"
  end

  def statistics_match_meta(match)
    return "-" if match.blank?

    tag.span(class: "statistics-card-meta") do
      safe_join(
        [
          match.match_day.played_on.to_s,
          tag.span("·", class: "statistics-card-meta__separator"),
          link_to("##{match.id}", match_path(match), class: "statistics-match-link")
        ],
        " "
      )
    end
  end

  def statistics_chart_data(data)
    json_escape(data.to_json)
  end

  private

  def statistics_sort_column(tab, column)
    return nil unless STATISTICS_SORT_COLUMNS.fetch(tab.to_s, []).include?(column.to_s.to_sym)

    column.to_sym
  end

  def statistics_sort_direction(direction)
    direction.to_s.in?(%w[asc desc]) ? direction.to_s : nil
  end

  def statistics_next_sort_direction(column, sort_column, sort_direction)
    return sort_direction.to_s == "asc" ? "desc" : "asc" if sort_column.to_s == column.to_s

    %i[record match_or_player player state example_match].include?(column.to_sym) ? "asc" : "desc"
  end

  def statistics_sort_indicator(column, sort_column, sort_direction)
    direction = statistics_sort_direction(sort_direction)
    return if direction.blank? || sort_column.to_s != column.to_s

    indicator = direction == "asc" ? "↑" : "↓"

    tag.span(indicator, class: "leaderboards-sort-indicator", aria: { hidden: true })
  end

  def statistics_sort_value(row, tab, column)
    case tab.to_s
    when "tempo", "records"
      case column
      when :record
        I18n.t("statistics.index.records.#{row.fetch(:key)}").downcase
      when :match_or_player
        row.fetch(:subject).to_s.downcase
      when :value
        statistics_value_sort_key(row.fetch(:value))
      end
    when "first_goal"
      case column
      when :player
        row.fetch(:player).name.to_s.downcase
      else
        row.fetch(column).to_f
      end
    when "comebacks"
      case column
      when :deficit
        row.fetch(:deficit).to_s.split(":").last.to_i
      when :example_match
        row.fetch(:examples).first&.fetch(:subject).to_s.downcase
      else
        row.fetch(column).to_f
      end
    when "score_states"
      case column
      when :state
        row.fetch(:state).to_s.split(":").map(&:to_i)
      else
        row.fetch(column).to_f
      end
    when "clutch"
      case column
      when :player
        row.fetch(:player).name.to_s.downcase
      else
        row.fetch(column).to_f
      end
    end
  end

  def statistics_value_sort_key(value)
    text = value.to_s
    clock_match = text.match(/\A(\d+):(\d+)\z/)
    return clock_match[1].to_i * 60 + clock_match[2].to_i if clock_match

    number_match = text.match(/\A([+-]?\d+)/)
    return number_match[1].to_i if number_match

    text.downcase
  end
end
