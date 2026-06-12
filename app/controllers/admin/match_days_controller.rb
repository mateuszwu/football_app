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
      form_state = form_state_for(match_day, players)

      render :new, locals: form_locals(match_day:, seasons:, players:, form_state:)
    end

    def create
      match_day = MatchDay.new(match_day_params)
      seasons = available_seasons
      players = available_players
      form_state = form_state_for(match_day, players)

      if form_state.preview_auto_proposal_requested?
        render :new, locals: form_locals(match_day:, seasons:, players:, form_state:)
        return
      end

      if CreateMatchDay.call(match_day:, params: form_state.form_params, available_players: players)
        redirect_to admin_match_days_path, notice: "Match day created"
      else
        render :new, locals: form_locals(match_day:, seasons:, players:, form_state:), status: :unprocessable_content
      end
    end

    def edit
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons
      players = available_players
      form_state = form_state_for(match_day, players)

      render :edit, locals: form_locals(match_day:, seasons:, players:, form_state:)
    end

    def update
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons
      players = available_players
      form_state = form_state_for(match_day, players)

      if form_state.preview_auto_proposal_requested?
        match_day.assign_attributes(match_day_params)
        render :edit, locals: form_locals(match_day:, seasons:, players:, form_state:)
        return
      end

      if UpdateMatchDay.call(match_day:, params: form_state.form_params, available_players: players)
        redirect_to admin_match_days_path, notice: "Match day updated"
      else
        render :edit, locals: form_locals(match_day:, seasons:, players:, form_state:), status: :unprocessable_content
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

    def form_locals(match_day:, seasons:, players:, form_state:)
      {
        match_day:,
        seasons:,
        players:,
        **form_state.locals
      }
    end

    def form_state_for(match_day, players)
      Admin::MatchDays::FormState.new(match_day:, params:, players:)
    end
  end
end
