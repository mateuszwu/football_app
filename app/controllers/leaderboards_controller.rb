class LeaderboardsController < ApplicationController
  def index
    available_seasons = Season.order(starts_on: :desc, created_at: :desc)
    season = selected_season(available_seasons)
    leaderboards = season.present? ? cached_leaderboards_for(season) : nil

    render :index, locals: {
      available_seasons:,
      leaderboards:,
      season:,
      active_tab: active_tab,
      sort_column: params[:sort].to_s.presence,
      sort_direction: params[:sort_direction].to_s.presence
    }
  end

  private

  def cached_leaderboards_for(season)
    Rails.cache.fetch([ "leaderboards", season.id, PublicStats::CacheKey.season(season) ], expires_in: 10.minutes) do
      Seasons::PublicLeaderboardQuery.call(season:)
    end
  end

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
