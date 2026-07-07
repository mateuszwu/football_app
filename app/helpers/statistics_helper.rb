module StatisticsHelper
  def statistics_tabs
    Stats::SeasonInsightsQuery::TABS
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

  def statistics_chart_data(data)
    json_escape(data.to_json)
  end
end
