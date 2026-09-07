class LeaderboardsController < ApplicationController
  def index
    available_seasons = Season.order(starts_on: :desc, created_at: :desc)
    season = selected_season(available_seasons)
    attendance_percent = normalized_attendance_percent
    leaderboards = season.present? ? cached_leaderboards_for(season, attendance_percent:) : nil

    render :index, locals: {
      available_seasons:,
      leaderboards:,
      season:,
      active_tab: active_tab,
      sort_column: params[:sort].to_s.presence,
      sort_direction: params[:sort_direction].to_s.presence,
      attendance_percent:
    }
  end

  private

  def cached_leaderboards_for(season, attendance_percent:)
    Rails.cache.fetch([ "leaderboards", "v3", season.id, attendance_percent, PublicStats::CacheKey.season(season) ], expires_in: 10.minutes) do
      Seasons::PublicLeaderboardQuery.call(season:, attendance_percent:)
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

  def normalized_attendance_percent
    Seasons::PublicLeaderboardQuery.normalize_attendance_percent(params[:attendance_percent])
  end
end
