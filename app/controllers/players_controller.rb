class PlayersController < ApplicationController
  def new
    player = Player.new(role_code: "ANY")

    render :new, locals: { player: player }
  end

  def create
    player = Player.new(player_params)

    if player.save
      cookies.encrypted[:pending_player_edit_token] = {
        value: Players::GenerateEditToken.call(player: player),
        expires: Players::GenerateEditToken::EXPIRATION.from_now,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }

      redirect_to edit_player_path(player), notice: "Zgloszenie zawodnika zostalo zapisane i czeka na akceptacje."
    else
      render :new, locals: { player: player }, status: :unprocessable_content
    end
  end

  def edit
    player = pending_player_for_current_device!
    return if performed?

    render :edit, locals: { player: player }
  end

  def update
    player = pending_player_for_current_device!
    return if performed?

    if player.update(player_params)
      redirect_to edit_player_path(player), notice: "Zgloszenie zawodnika zostalo zaktualizowane."
    else
      render :edit, locals: { player: player }, status: :unprocessable_content
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

  def pending_player_for_current_device!
    payload = Players::DecodeEditToken.call(token: cookies.encrypted[:pending_player_edit_token])
    player = Player.pending.find_by(id: params[:id])

    return redirect_to(new_player_path, alert: "Brak dostepu do edycji tego zgloszenia.") if payload.blank? || player.blank?
    return redirect_to(new_player_path, alert: "Brak dostepu do edycji tego zgloszenia.") if payload.fetch("player_id", nil) != player.id

    player
  end
end
