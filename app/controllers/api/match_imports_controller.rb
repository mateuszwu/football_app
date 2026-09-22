module Api
  class MatchImportsController < BaseController
    def create
      season = Season.find_by(id: import_payload[:season_id])
      result = MatchDays::ImportFromPayload.call(
        payload: import_payload,
        season:,
        available_players: Player.approved.active.order(:name)
      )

      if result.success?
        render json: success_payload(result), status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end

    private

    def import_payload
      @import_payload ||= params.permit(
        :season_id,
        :played_on,
        :started_at,
        :finished_at,
        :all_roster_players_on_pitch,
        original_teams: [ :name, :captain, { players: [] } ],
        teams: [ :name, :captain, { players: [] } ],
        goals: %i[team scorer assistant scored_at own_goal],
        player_changes: %i[player from_team to_team occurred_at],
        matches: [
          :started_at,
          :finished_at,
          :all_roster_players_on_pitch,
          {
            teams: [ :name, :captain, { players: [] } ],
            goals: %i[team scorer assistant scored_at own_goal],
            player_changes: %i[player from_team to_team occurred_at]
          }
        ]
      ).to_h
    end

    def success_payload(result)
      {
        match_day_id: result.match_day.id,
        status: result.match_day.status,
        matches: result.matches.map { |match| match_payload(match) }
      }
    end

    def match_payload(match)
      payload = {
        match_id: match.id,
        match_url: match_url(match),
        status: match.status,
        score: {
          home: match.home_score,
          away: match.away_score
        },
        all_roster_players_on_pitch: match.all_roster_players_on_pitch?
      }

      changes = match.match_player_changes.includes(:player, :from_team, :to_team).order(:occurred_at, :id)
      payload[:player_changes] = changes.map do |change|
        {
          "player" => change.player.nickname,
          "from_team" => change.from_team&.name,
          "to_team" => change.to_team&.name,
          "event_type" => change.event_type,
          "occurred_at" => change.occurred_at.iso8601
        }
      end if changes.any?

      payload
    end
  end
end
