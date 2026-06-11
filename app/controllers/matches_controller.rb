class MatchesController < ApplicationController
  before_action :require_admin!, only: :finish

  def show
    match = Match
      .includes(
        match_day: :season,
        home_team: :players,
        away_team: :players
      )
      .find(params[:id])

    render :show, locals: { match: match }
  end

  def finish
    match = Match.find(params[:id])

    if Matches::FinishMatch.call(match:)
      redirect_to match_path(match), notice: "Match finished"
    else
      redirect_to match_path(match), alert: "Could not finish match"
    end
  end
end
