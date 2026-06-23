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
end
