class StatisticsController < ApplicationController
  def index
    available_seasons = Season.order(starts_on: :desc, created_at: :desc)
    season = selected_season(available_seasons)
    insights = season.present? ? Stats::SeasonInsightsQuery.call(season:) : nil

    render :index, locals: {
      active_tab:,
      available_seasons:,
      insights:,
      season:
    }
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
    Stats::SeasonInsightsQuery::TABS.include?(params[:tab].to_s) ? params[:tab].to_s : "tempo"
  end
end
