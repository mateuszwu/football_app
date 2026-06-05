module Admin
  class MatchDaysController < ApplicationController
    before_action :require_admin!

    def index
      match_days = MatchDay.includes(:season).order(played_on: :desc, created_at: :desc)

      render :index, locals: { match_days: match_days }
    end

    def new
      match_day = MatchDay.new(season: current_season, played_on: Date.current)
      seasons = available_seasons

      render :new, locals: { match_day: match_day, seasons: seasons }
    end

    def create
      match_day = MatchDay.new(match_day_params)
      seasons = available_seasons

      if match_day.save
        redirect_to admin_match_days_path, notice: "Match day created"
      else
        render :new, locals: { match_day: match_day, seasons: seasons }, status: :unprocessable_content
      end
    end

    def edit
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons

      render :edit, locals: { match_day: match_day, seasons: seasons }
    end

    def update
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons

      if match_day.update(match_day_params)
        redirect_to admin_match_days_path, notice: "Match day updated"
      else
        render :edit, locals: { match_day: match_day, seasons: seasons }, status: :unprocessable_content
      end
    end

    private

    def available_seasons
      Season.order(starts_on: :desc, name: :asc)
    end

    def match_day_params
      params.require(:match_day).permit(:season_id, :played_on)
    end
  end
end
