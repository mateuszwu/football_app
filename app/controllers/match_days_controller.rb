class MatchDaysController < ApplicationController
  def show
    match_day = MatchDay
      .includes(:season)
      .find(params[:id])
    report = MatchDays::ShowQuery.call(match_day:)

    render :show, locals: { report: }
  end
end
