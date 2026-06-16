class SeasonsController < ApplicationController
  def show
    season = Season.find(params[:season_id].presence || params[:id])
    available_seasons = Season.order(starts_on: :desc, created_at: :desc)
    leaderboards = Seasons::PublicLeaderboardQuery.call(season:)
    recent_match_days = season.recent_match_days.includes(:players)

    render :show, locals: { available_seasons:, leaderboards:, recent_match_days:, season: }
  end
end
