module MatchDaysHelper
  def match_day_date(date)
    l(date, format: :short)
  end

  def match_day_time_range(match_row)
    start_time = match_report_clock(match_row.start_time)
    end_time = match_report_clock(match_row.end_time)

    "#{start_time} - #{end_time}"
  end

  def match_day_total_duration(seconds)
    seconds = seconds.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    return "#{minutes}m" if hours.zero?
    return "#{hours}h" if minutes.zero?

    "#{hours}h #{minutes}m"
  end

  def match_day_player_link(player, class_name: nil)
    match_player_profile_link(player, class_name:)
  end
end
