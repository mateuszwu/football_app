module Api
  class SeasonsController < BaseController
    def active
      season = Season.current_active

      if season
        render json: season_payload(season)
      else
        render json: { errors: [ "Active season not found" ] }, status: :not_found
      end
    end

    def create
      season = Season.new(season_params)

      if season.save
        render json: season_payload(season), status: :created
      else
        render json: { errors: season.errors.to_hash(true) }, status: :unprocessable_content
      end
    end

    private

    def season_params
      source = params[:season].presence || params

      source.permit(
        :name,
        :starts_on,
        :ends_on,
        :status,
        :initial_elo,
        :elo_k_factor,
        :mvp_vote_bonus,
        :def_vote_bonus,
        :elo_k_value,
        :player_advantage_elo,
        :season_elo_carryover_factor,
        :goal_points,
        :assist_points,
        :mvp_max_points,
        :def_max_points,
        :voting_bonus_cap,
        :expected_voters_count,
        :elo_settings_locked
      )
    end

    def season_payload(season)
      {
        id: season.id,
        name: season.name,
        starts_on: season.starts_on,
        ends_on: season.ends_on,
        status: season.status,
        initial_elo: season.initial_elo,
        elo_k_factor: season.elo_k_factor,
        elo_k_value: season.elo_k_value.to_s,
        player_advantage_elo: season.player_advantage_elo.to_s,
        season_elo_carryover_factor: season.season_elo_carryover_factor.to_s,
        goal_points: season.goal_points.to_s,
        assist_points: season.assist_points.to_s,
        mvp_max_points: season.mvp_max_points.to_s,
        def_max_points: season.def_max_points.to_s,
        voting_bonus_cap: season.voting_bonus_cap.to_s,
        expected_voters_count: season.expected_voters_count,
        mvp_vote_bonus: season.mvp_vote_bonus,
        def_vote_bonus: season.def_vote_bonus,
        elo_settings_locked: season.elo_settings_locked
      }
    end
  end
end
