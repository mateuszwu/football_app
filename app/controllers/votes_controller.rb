class VotesController < ApplicationController
  def show
    match_day_vote_token = find_vote_token
    vote = match_day_vote_token.match_day_vote || MatchDayVote.new
    selectable_players = match_day_vote_token.match_day_player.match_day.players.order(:name)

    render :show, locals: { match_day_vote_token: match_day_vote_token, selectable_players: selectable_players, vote: vote }
  end

  def create
    match_day_vote_token = find_vote_token
    vote = match_day_vote_token.match_day_vote || MatchDayVote.new(match_day_vote_token: match_day_vote_token)
    selectable_players = match_day_vote_token.match_day_player.match_day.players.order(:name)

    if vote.update(vote_params.merge(match_day_vote_token: match_day_vote_token))
      redirect_to vote_path(match_day_vote_token.token), notice: "Glos zapisany"
    else
      render :show, locals: { match_day_vote_token: match_day_vote_token, selectable_players: selectable_players, vote: vote }, status: :unprocessable_content
    end
  end

  private

  def find_vote_token
    MatchDayVoteToken
      .includes(match_day_player: [ :player, { match_day: :players } ])
      .find_by!(token: params[:token])
  end

  def vote_params
    params.require(:match_day_vote).permit(:mvp_player_id, :def_player_id)
  end
end
