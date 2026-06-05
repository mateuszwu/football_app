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

      if player.update(player_params)
        redirect_to admin_players_path, notice: "Player updated"
      else
        render :edit, locals: { player: player }, status: :unprocessable_content
      end
    end

    def approve
      player = Player.find(params[:id])
      player.update!(approval_status: "approved")

      redirect_to admin_players_path, notice: "Player approved"
    end

    def reject
      player = Player.find(params[:id])
      player.update!(approval_status: "rejected")

      redirect_to admin_players_path, notice: "Player rejected"
    end

    private

    def player_params
      params.require(:player).permit(:name, :nickname, :phone, :description, :role_code, :approval_status, :active)
    end
  end
end
