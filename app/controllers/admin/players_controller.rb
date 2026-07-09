module Admin
  class PlayersController < ApplicationController
    before_action :require_admin!

    def index
      players = Player.order(:name)

      render :index, locals: { players: players }
    end

    def edit
      player = Player.find(params[:id])

      render :edit, locals: { player: player }
    end

    def update
      player = Player.find(params[:id])

      sync_identity_color_hex

      if player.update(player_params)
        redirect_to admin_players_path, notice: t("admin.player_updated")
      else
        render :edit, locals: { player: player }, status: :unprocessable_content
      end
    end

    def approve
      player = Player.find(params[:id])
      player.update!(approval_status: "approved", approved_at: Time.current, rejected_at: nil, active: true)

      redirect_to admin_players_path, notice: t("admin.player_approved")
    end

    def reject
      player = Player.find(params[:id])
      player.update!(approval_status: "rejected", rejected_at: Time.current, approved_at: nil, active: false)

      redirect_to admin_players_path, notice: t("admin.player_rejected")
    end

    private

    def player_params
      params.require(:player).permit(
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

    def sync_identity_color_hex
      player_params = params[:player]
      return if player_params.blank?

      color_key = player_params[:profile_color_key]
      return if color_key.blank?

      player_params[:profile_color_hex] = PlayerIdentity.hex_for(color_key)
    end
  end
end
