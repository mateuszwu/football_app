class MatchDaysController < ApplicationController
  def show
    match_day = MatchDay
      .includes(:season)
      .find(params[:id])
    report = MatchDays::ShowQuery.call(match_day:)
    show_all_players = params[:show_all_players] == "1"

    render :show, locals: { report:, show_all_players: }
  end
end
