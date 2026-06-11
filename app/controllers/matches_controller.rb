class MatchesController < ApplicationController
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
end
