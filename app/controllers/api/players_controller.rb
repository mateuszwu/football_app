module Api
  class PlayersController < BaseController
    def create
      player = Player.new(player_params)

      if player.save
        render json: player_payload(player), status: :created
      else
        render json: { errors: player.errors.to_hash(true) }, status: :unprocessable_content
      end
    end

    private

    def player_params
      source = params[:player].presence || params

      source.permit(
        :name,
        :nickname,
        :phone,
        :description,
        :role_code,
        :approval_status,
        :active,
        :profile_color_key,
        :profile_color_hex,
        :profile_icon
      )
    end

    def player_payload(player)
      {
        id: player.id,
        name: player.name,
        nickname: player.nickname,
        description: player.description,
        role_code: player.role_code,
        approval_status: player.approval_status,
        active: player.active,
        profile_color_key: player.profile_color_key,
        profile_color_hex: player.profile_color_hex,
        profile_icon: player.profile_icon
      }
    end
  end
end
