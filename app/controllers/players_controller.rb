class PlayersController < ApplicationController
  def show
    player = Player.approved.active.find(params[:id])
    match_history = player.match_history

    render :show, locals: { player: player, match_history: match_history }
  end
end
