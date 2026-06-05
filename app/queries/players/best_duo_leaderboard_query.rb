module Players
  class BestDuoLeaderboardQuery
    Duo = Struct.new(:player_one, :player_two, :shared_match_days_count, keyword_init: true)

    def self.call
      new.call
    end

    def call
      rows = duo_rows
      players_by_id = Player.where(id: player_ids(rows)).index_by(&:id)

      rows
        .map { |row| build_duo(row:, players_by_id:) }
        .sort_by { |duo| [ -duo.shared_match_days_count, duo.player_one.name, duo.player_two.name ] }
    end

    private

    def build_duo(row:, players_by_id:)
      player_one, player_two = [
        players_by_id.fetch(row.player_one_id),
        players_by_id.fetch(row.player_two_id)
      ].sort_by(&:name)

      Duo.new(
        player_one: player_one,
        player_two: player_two,
        shared_match_days_count: row.shared_match_days_count.to_i
      )
    end

    def duo_rows
      MatchDayPlayer
        .joins(<<~SQL.squish)
          INNER JOIN match_day_players teammate_match_day_players
            ON teammate_match_day_players.match_day_id = match_day_players.match_day_id
           AND teammate_match_day_players.player_id > match_day_players.player_id
        SQL
        .joins("INNER JOIN players first_players ON first_players.id = match_day_players.player_id")
        .joins("INNER JOIN players second_players ON second_players.id = teammate_match_day_players.player_id")
        .select(
          "match_day_players.player_id AS player_one_id, " \
          "teammate_match_day_players.player_id AS player_two_id, " \
          "first_players.name AS player_one_name, " \
          "second_players.name AS player_two_name, " \
          "COUNT(DISTINCT match_day_players.match_day_id) AS shared_match_days_count"
        )
        .group(
          "match_day_players.player_id, " \
          "teammate_match_day_players.player_id, " \
          "first_players.name, " \
          "second_players.name"
        )
        .order(Arel.sql("shared_match_days_count DESC"), Arel.sql("player_one_name ASC"), Arel.sql("player_two_name ASC"))
    end

    def player_ids(rows)
      rows.flat_map { |row| [ row.player_one_id, row.player_two_id ] }.uniq
    end
  end
end
