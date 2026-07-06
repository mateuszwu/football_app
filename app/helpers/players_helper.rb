module PlayersHelper
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
end
