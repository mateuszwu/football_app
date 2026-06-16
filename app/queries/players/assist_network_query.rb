module Players
  class AssistNetworkQuery
    Edge = Struct.new(:assistant, :scorer, :assists_count, keyword_init: true)

    def self.call(season: nil)
      new(season:).call
    end

    def initialize(season:)
      @season = season
    end

    def call
      rows = assist_rows
      players_by_id = Player.where(id: player_ids(rows)).index_by(&:id)

      rows.map do |row|
        Edge.new(
          assistant: players_by_id.fetch(row.assistant_id),
          scorer: players_by_id.fetch(row.scorer_id),
          assists_count: row.assists_count.to_i
        )
      end
    end

    private

    attr_reader :season

    def assist_rows
      scope = MatchGoal.active
                       .joins(match: :match_day)
                       .joins("INNER JOIN team_players assistant_team_players ON assistant_team_players.id = match_goals.assistant_team_player_id")
                       .joins("INNER JOIN team_players scorer_team_players ON scorer_team_players.id = match_goals.scorer_team_player_id")
                       .where.not(assistant_team_player_id: nil)
                       .select(
                         "assistant_team_players.player_id AS assistant_id, " \
                         "scorer_team_players.player_id AS scorer_id, " \
                         "COUNT(match_goals.id) AS assists_count"
                       )
                       .group("assistant_team_players.player_id, scorer_team_players.player_id")
                       .order(Arel.sql("assists_count DESC"), Arel.sql("assistant_id ASC"), Arel.sql("scorer_id ASC"))

      return scope unless season.present?

      scope.where(match_days: { season_id: season.id })
    end

    def player_ids(rows)
      rows.flat_map { |row| [ row.assistant_id, row.scorer_id ] }.uniq
    end
  end
end
