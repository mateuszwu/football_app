module SeasonsHelper
  def season_summary_date(date)
    return "—" if date.blank?

    l(date, format: :short)
  end

  def season_summary_duration(seconds)
    return "—" if seconds.blank?

    minutes = (seconds.to_i / 60.0).round

    t("seasons.show.summary.duration_minutes", count: minutes)
  end

  def season_total_duration(seconds)
    seconds = seconds.to_i
    return "—" if seconds.zero?

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    return "#{minutes}m" if hours.zero?
    return "#{hours}h" if minutes.zero?

    "#{hours}h #{minutes}m"
  end

  def season_average_players(value)
    return "—" if value.blank?

    format("%.1f", value)
  end
end
