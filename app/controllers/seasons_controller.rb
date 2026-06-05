class SeasonsController < ApplicationController
  def show
    season = Season.find(params[:id])
    appearances_leaderboard = season.appearances_leaderboard
    recent_match_days = season.recent_match_days.includes(:players)

    render :show, locals: { appearances_leaderboard: appearances_leaderboard, recent_match_days: recent_match_days, season: season }
  end
end
