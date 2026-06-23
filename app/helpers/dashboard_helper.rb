module DashboardHelper
  ICON_PATHS = {
    "calendar-days" => [
      [ :path, { d: "M8 2v4" } ],
      [ :path, { d: "M16 2v4" } ],
      [ :rect, { x: "3", y: "4", width: "18", height: "18", rx: "2" } ],
      [ :path, { d: "M3 10h18" } ],
      [ :path, { d: "M8 14h.01" } ],
      [ :path, { d: "M12 14h.01" } ],
      [ :path, { d: "M16 14h.01" } ],
      [ :path, { d: "M8 18h.01" } ],
      [ :path, { d: "M12 18h.01" } ],
      [ :path, { d: "M16 18h.01" } ]
    ],
    "calendar-check" => [
      [ :path, { d: "M8 2v4" } ],
      [ :path, { d: "M16 2v4" } ],
      [ :rect, { x: "3", y: "4", width: "18", height: "18", rx: "2" } ],
      [ :path, { d: "M3 10h18" } ],
      [ :path, { d: "m9 16 2 2 4-4" } ]
    ],
    "circle-dot" => [
      [ :circle, { cx: "12", cy: "12", r: "10" } ],
      [ :circle, { cx: "12", cy: "12", r: "3" } ]
    ],
    "crown" => [
      [ :path, { d: "m2 4 3 12h14l3-12-6 7-4-7-4 7-6-7Z" } ],
      [ :path, { d: "M5 20h14" } ]
    ],
    "network" => [
      [ :rect, { x: "16", y: "16", width: "6", height: "6", rx: "1" } ],
      [ :rect, { x: "2", y: "16", width: "6", height: "6", rx: "1" } ],
      [ :rect, { x: "9", y: "2", width: "6", height: "6", rx: "1" } ],
      [ :path, { d: "M5 16v-3a7 7 0 0 1 14 0v3" } ],
      [ :path, { d: "M12 8v8" } ]
    ],
    "shield" => [
      [ :path, { d: "M20 13c0 5-3.5 7.5-8 9-4.5-1.5-8-4-8-9V5l8-3 8 3v8Z" } ]
    ],
    "shield-check" => [
      [ :path, { d: "M20 13c0 5-3.5 7.5-8 9-4.5-1.5-8-4-8-9V5l8-3 8 3v8Z" } ],
      [ :path, { d: "m9 12 2 2 4-4" } ]
    ],
    "target" => [
      [ :circle, { cx: "12", cy: "12", r: "10" } ],
      [ :circle, { cx: "12", cy: "12", r: "6" } ],
      [ :circle, { cx: "12", cy: "12", r: "2" } ]
    ],
    "trending-up" => [
      [ :path, { d: "m3 17 6-6 4 4 8-8" } ],
      [ :path, { d: "M14 7h7v7" } ]
    ],
    "trophy" => [
      [ :path, { d: "M8 21h8" } ],
      [ :path, { d: "M12 17v4" } ],
      [ :path, { d: "M7 4h10v7a5 5 0 0 1-10 0V4Z" } ],
      [ :path, { d: "M5 9a3 3 0 0 1-3-3V5h5" } ],
      [ :path, { d: "M19 9a3 3 0 0 0 3-3V5h-5" } ]
    ],
    "user-plus" => [
      [ :path, { d: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" } ],
      [ :circle, { cx: "9", cy: "7", r: "4" } ],
      [ :path, { d: "M19 8v6" } ],
      [ :path, { d: "M22 11h-6" } ]
    ],
    "users" => [
      [ :path, { d: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" } ],
      [ :circle, { cx: "9", cy: "7", r: "4" } ],
      [ :path, { d: "M22 21v-2a4 4 0 0 0-3-3.87" } ],
      [ :path, { d: "M16 3.13a4 4 0 0 1 0 7.75" } ]
    ],
    "vote" => [
      [ :path, { d: "m9 12 2 2 4-4" } ],
      [ :path, { d: "M9 7h6" } ],
      [ :path, { d: "M5 4h14v16H5z" } ],
      [ :path, { d: "M3 20h18" } ]
    ]
  }.freeze

  def dashboard_icon(name, class_name: "tile-icon")
    paths = ICON_PATHS.fetch(name).map { |element_name, attributes| tag.public_send(element_name, **attributes) }
    tag.span(class: class_name, aria: { hidden: true }) do
      tag.svg(
        safe_join(paths),
        xmlns: "http://www.w3.org/2000/svg",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor",
        stroke_width: "2",
        stroke_linecap: "round",
        stroke_linejoin: "round",
        focusable: "false"
      )
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
end
