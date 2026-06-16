class VotesController < ApplicationController
  def show
    match_day_vote_token = find_vote_token
    return redirect_to vote_thank_you_path(match_day_vote_token.token) if match_day_vote_token.used?

    vote = match_day_vote_token.match_day_vote || MatchDayVote.new
    selectable_players = Votes::SelectablePlayersQuery.call(match_day_vote_token: match_day_vote_token)

    render :show, locals: { match_day_vote_token: match_day_vote_token, selectable_players: selectable_players, vote: vote }
  end

  def thank_you
    match_day_vote_token = find_vote_token

    render :thank_you, locals: { match_day_vote_token: match_day_vote_token }
  end

  def create
    match_day_vote_token = find_vote_token
    return redirect_to vote_thank_you_path(match_day_vote_token.token) if match_day_vote_token.used?

    vote = match_day_vote_token.match_day_vote || MatchDayVote.new(match_day_vote_token: match_day_vote_token)
    selectable_players = Votes::SelectablePlayersQuery.call(match_day_vote_token: match_day_vote_token)
    vote.assign_attributes(vote_params.merge(match_day_vote_token: match_day_vote_token))

    if vote.valid?
      save_vote!(vote, match_day_vote_token)
      redirect_to vote_thank_you_path(match_day_vote_token.token), notice: "Glos zapisany"
    else
      render :show, locals: { match_day_vote_token: match_day_vote_token, selectable_players: selectable_players, vote: vote }, status: :unprocessable_content
    end
  end

  private

  def find_vote_token
    match_day_vote_token = MatchDayVoteToken
      .includes(match_day_player: [ :player, { match_day: :players } ])
      .find_by!(token: params[:token])

    raise ActiveRecord::RecordNotFound if match_day_vote_token.expired?

    match_day_vote_token
  end

  def vote_params
    params.require(:match_day_vote).permit(:mvp_player_id, :def_player_id)
  end

  def save_vote!(vote, match_day_vote_token)
    MatchDayVote.transaction do
      vote.save!
      match_day_vote_token.mark_used!
      Voting::CalculateVoteBonuses.call(match_day: match_day_vote_token.match_day_player.match_day)
    end
  end
end
