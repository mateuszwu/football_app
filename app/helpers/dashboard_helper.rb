require "lucide-rails"

module DashboardHelper
  def dashboard_icon(name, class_name: "tile-icon")
    safe_lucide_icon(name, fallback: "circle", class_name:)
  end

  def safe_lucide_icon(name, fallback: "circle", class_name: "ui-icon")
    tag.span(class: class_name, aria: { hidden: true }) do
      render_lucide_icon_with_fallback(name.to_s, fallback.to_s)
    end
  end

  def dashboard_polish_count(count, one:, few:, many:)
    noun = if count == 1
      one
    elsif (count % 10).between?(2, 4) && !(count % 100).between?(12, 14)
      few
    else
      many
    end

    "#{count} #{noun}"
  end

  def dashboard_count(key, count)
    t("dashboard.labels.#{key}", count:)
  end

  private

  def render_lucide_icon_with_fallback(name, fallback)
    render_lucide_icon(name)
  rescue ArgumentError => error
    raise unless unknown_lucide_icon?(error)

    begin
      render_lucide_icon(fallback)
    rescue ArgumentError => fallback_error
      raise unless unknown_lucide_icon?(fallback_error)

      render_lucide_icon("circle")
    end
  end

  def render_lucide_icon(name)
    content_tag(
      :svg,
      LucideRails::IconProvider.icon(name).html_safe,
      LucideRails.default_options.merge("class" => "lucide lucide-#{name}", "focusable" => "false")
    )
  end

  def unknown_lucide_icon?(error)
    error.message.start_with?("Unknown icon ")
  end
end
