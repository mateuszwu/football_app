module ApplicationHelper
  def ranked_entry_display_value(ranked_entry)
    ranked_entry.value.presence || "-"
  end

  def status_label(status)
    normalized_status = status.to_s.downcase

    t("statuses.#{normalized_status}", default: status.to_s.humanize)
  end

  def role_label(role_code)
    normalized_role = role_code.to_s.downcase

    t("roles.#{normalized_role}", default: role_code.to_s)
  end

  def role_options(role_codes)
    role_codes.map { |role_code| [ role_label(role_code), role_code ] }
  end

  def status_options(statuses)
    statuses.map { |status| [ status_label(status), status ] }
  end

  def yes_no_label(value)
    value ? t("common.yes") : t("common.no")
  end

  def public_join_enabled?
    false
  end

  def player_identity_badge(player, size: :md, label: nil)
    tag.span(
      class: "player-identity-badge player-identity-badge--#{size}",
      style: "--player-color: #{player.profile_color}",
      title: label.presence || player.name,
      aria: { label: label.presence || player.name }
    ) do
      safe_lucide_icon(player.profile_icon_name, fallback: PlayerIdentity::DEFAULT_ICON, class_name: "player-identity-badge__icon")
    end
  end
end
