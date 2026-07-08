class SeasonsController < ApplicationController
  def show
    season = Season.find(params[:season_id].presence || params[:id])
    season_report = Seasons::ShowQuery.call(season:, sort_direction: params[:sort])

    render :show, locals: { season:, season_report: }
  end
end
