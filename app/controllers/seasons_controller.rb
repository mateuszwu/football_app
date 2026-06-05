class SeasonsController < ApplicationController
  def show
    season = Season.find(params[:id])
    recent_match_days = season.recent_match_days.includes(:players)

    render :show, locals: { season: season, recent_match_days: recent_match_days }
  end
end
