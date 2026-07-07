module MatchesHelper
  def match_report_clock(time)
    return "—" if time.blank?

    time.strftime("%H:%M")
  end

  def match_report_duration(seconds)
    seconds = seconds.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    remainder_seconds = seconds % 60

    return format("%02d:%02d", minutes, remainder_seconds) if hours.zero?

    format("%02d:%02d:%02d", hours, minutes, remainder_seconds)
  end

  def match_report_minute(seconds)
    return "—" if seconds.blank?

    "#{(seconds.to_i / 60) + 1}'"
  end

  def match_report_score(score_hash)
    "#{score_hash.fetch(:team_a)} : #{score_hash.fetch(:team_b)}"
  end

  def match_report_compact_score(score_hash)
    "#{score_hash.fetch(:team_a)}:#{score_hash.fetch(:team_b)}"
  end

  def match_player_profile_link(player, class_name: nil)
    return player.name unless player.active? && player.approval_status == "approved"

    link_to player.name, player_path(player), class: class_name
  end

  def match_player_initials(player)
    player.name.to_s.split.first(2).map { |part| part.first.to_s.upcase }.join.presence || "?"
  end

  def match_report_votes_count(count)
    noun = if count == 1
      "głos"
    elsif (count % 10).between?(2, 4) && !(count % 100).between?(12, 14)
      "głosy"
    else
      "głosów"
    end

    "#{count} #{noun}"
  end
end
