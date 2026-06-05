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
      players = available_players

      render :new, locals: { match_day: match_day, seasons: seasons, players: players }
    end

    def create
      match_day = MatchDay.new(match_day_params)
      seasons = available_seasons
      players = available_players

      if CreateMatchDay.call(match_day:, params: match_day_form_params, available_players: players)
        redirect_to admin_match_days_path, notice: "Match day created"
      else
        render :new, locals: { match_day: match_day, seasons: seasons, players: players }, status: :unprocessable_content
      end
    end

    def edit
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons
      players = available_players

      render :edit, locals: { match_day: match_day, seasons: seasons, players: players }
    end

    def update
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons
      players = available_players

      if UpdateMatchDay.call(match_day:, params: match_day_form_params, available_players: players)
        redirect_to admin_match_days_path, notice: "Match day updated"
      else
        render :edit, locals: { match_day: match_day, seasons: seasons, players: players }, status: :unprocessable_content
      end
    end

    private

    def available_seasons
      Season.order(starts_on: :desc, name: :asc)
    end

    def available_players
      Player.approved.active.order(:name)
    end

    def match_day_params
      params.require(:match_day).permit(:season_id, :played_on)
    end

    def match_day_form_params
      match_day_params.to_h.symbolize_keys.merge(
        player_ids: params.fetch(:match_day, {}).fetch(:player_ids, [])
      )
    end
  end
end
