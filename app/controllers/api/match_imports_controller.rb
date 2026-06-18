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
        original_teams: [ :name, { players: [] } ],
        teams: [ :name, { players: [] } ],
        goals: %i[team scorer assistant],
        matches: [
          :started_at,
          :finished_at,
          {
            teams: [ :name, { players: [] } ],
            goals: %i[team scorer assistant]
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
      {
        match_id: match.id,
        match_url: match_url(match),
        status: match.status,
        score: {
          home: match.home_score,
          away: match.away_score
        }
      }
    end
  end
end
