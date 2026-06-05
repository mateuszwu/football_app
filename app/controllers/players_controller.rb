class PlayersController < ApplicationController
  def show
    player = Player.approved.active.find(params[:id])

    render :show, locals: { player: player }
  end
end
