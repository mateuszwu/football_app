module Api
  class PlayersController < BaseController
    def index
      players = Player.order(:name, :id)
      players = players.where(approval_status: params[:approval_status]) if params[:approval_status].present?
      players = players.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)

      if params[:search].present?
        search = ActiveRecord::Base.sanitize_sql_like(params[:search].to_s.downcase)
        players = players.where(
          "LOWER(players.name) LIKE :search OR LOWER(players.nickname) LIKE :search",
          search: "%#{search}%"
        )
      end

      render json: { players: players.map { |player| player_payload(player) }, count: players.size }
    end

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
