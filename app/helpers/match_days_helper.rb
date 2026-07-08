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

  def match_day_event_text(event)
    if event.own_goal
      t("match_days.show.match_card.own_goal", player: event.scorer.name)
    elsif event.assister.present?
      t("match_days.show.match_card.goal_with_assist", player: event.scorer.name, assistant: event.assister.name)
    else
      t("match_days.show.match_card.goal", player: event.scorer.name)
    end
  end
end
