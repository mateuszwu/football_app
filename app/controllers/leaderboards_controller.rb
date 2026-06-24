class LeaderboardsController < ApplicationController
  def index
    available_seasons = Season.order(starts_on: :desc, created_at: :desc)
    season = selected_season(available_seasons)
    leaderboards = season.present? ? Seasons::PublicLeaderboardQuery.call(season:) : nil

    render :index, locals: { available_seasons:, leaderboards:, season:, active_tab: active_tab }
  end

  private

  def selected_season(available_seasons)
    if params[:season_id].present?
      available_seasons.find_by(id: params[:season_id])
    else
      Season.current_active || available_seasons.first
    end
  end

  def active_tab
    allowed_tabs = %w[elo goals assists goals_assists mvp def record]

    allowed_tabs.include?(params[:tab].to_s) ? params[:tab].to_s : "elo"
  end
end
