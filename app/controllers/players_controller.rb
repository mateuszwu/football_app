class PlayersController < ApplicationController
  def new
    player = Player.new(role_code: "ANY")

    render :new, locals: { player: player }
  end

  def create
    player = Player.new(player_params)

    if player.save
      cookies[:pending_player_edit_token] = {
        value: Players::GenerateEditToken.call(player: player),
        expires: Players::GenerateEditToken::EXPIRATION.from_now,
        httponly: true,
        same_site: :lax
      }

      redirect_to new_player_path, notice: "Zgloszenie zawodnika zostalo zapisane i czeka na akceptacje."
    else
      render :new, locals: { player: player }, status: :unprocessable_content
    end
  end

  def show
    player = Player.approved.active.find(params[:id])
    match_history = player.match_history

    render :show, locals: { player: player, match_history: match_history }
  end

  private

  def player_params
    params.require(:player).permit(:name, :nickname, :phone, :description, :role_code)
  end
end
