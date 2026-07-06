module PlayersHelper
  PLAYER_PROFILE_TABS = {
    "overview" => "layout-dashboard",
    "stats" => "chart-no-axes-combined",
    "matches" => "list-checks",
    "charts" => "chart-line",
    "elo" => "trending-up",
    "synergy" => "network",
    "awards" => "award"
  }.freeze

  def player_profile_tabs
    PLAYER_PROFILE_TABS
  end

  def player_directory_initials(player)
    player.name.split.map { |part| part.first }.join.first(2).upcase
  end

  def player_directory_elo(card)
    card.season_stat&.elo || card.player.elo || "—"
  end

  def player_directory_last_played(card)
    return t("players.directory.no_matches_short") if card.last_played_on.blank?

    l(card.last_played_on)
  end

  def player_directory_record(card)
    [ card.wins, card.draws, card.losses ].join("-")
  end

  def player_profile_initials(player)
    player_directory_initials(player)
  end

  def player_profile_tab_path(player, profile, tab)
    player_path(player, season_id: profile.season&.id, tab:)
  end

  def player_profile_result_label(result)
    case result
    when Team::RESULT_WIN then "W"
    when Team::RESULT_DRAW then "R"
    when Team::RESULT_LOSS then "P"
    else "—"
    end
  end

  def player_profile_signed_delta(value)
    return "—" if value.blank?

    value.to_i.positive? ? "+#{value.to_i}" : value.to_i.to_s
  end

  def player_profile_rate(value)
    number_with_precision(value.to_d, precision: 2, strip_insignificant_zeros: true)
  end

  def player_profile_partner(result, player)
    result.players.find { |partner| partner.id != player.id }
  end

  def player_profile_duo_names(result)
    result.players.map { |partner| link_to(partner.name, player_path(partner)) }.then { |links| safe_join(links, tag.span(" + ", class: "relationship-duo-card__plus")) }
  end

  def player_profile_chart_data(data)
    json_escape(data.to_json)
  end
end
