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

      render :new, locals: form_locals(match_day:, seasons:, players:)
    end

    def create
      match_day = MatchDay.new(match_day_params)
      seasons = available_seasons
      players = available_players

      if CreateMatchDay.call(match_day:, params: match_day_form_params, available_players: players)
        redirect_to admin_match_days_path, notice: "Match day created"
      else
        render :new, locals: form_locals(match_day:, seasons:, players:), status: :unprocessable_content
      end
    end

    def edit
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons
      players = available_players

      render :edit, locals: form_locals(match_day:, seasons:, players:)
    end

    def update
      match_day = MatchDay.find(params[:id])
      seasons = available_seasons
      players = available_players

      if UpdateMatchDay.call(match_day:, params: match_day_form_params, available_players: players)
        redirect_to admin_match_days_path, notice: "Match day updated"
      else
        render :edit, locals: form_locals(match_day:, seasons:, players:), status: :unprocessable_content
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
      teams_params = params.fetch(:match_day, {}).fetch(:teams_data, [])

      teams_data = if teams_params.is_a?(Hash)
                     teams_params.values
      else
                     Array(teams_params)
      end

      match_day_params.to_h.symbolize_keys.merge(
        player_ids: params.fetch(:match_day, {}).fetch(:player_ids, []),
        teams_data: teams_data.map { |t| { name: t[:name], player_ids: t[:player_ids] || [] } }
      )
    end

    def form_locals(match_day:, seasons:, players:)
      {
        match_day:,
        seasons:,
        players:,
        teams_data: current_teams_data(match_day)
      }
    end

    def current_teams_data(match_day)
      submitted_teams = params.fetch(:match_day, {}).fetch(:teams_data, nil)
      if submitted_teams
        if submitted_teams.is_a?(Hash)
          return submitted_teams.values.map { |t| { name: t[:name], player_ids: t[:player_ids] || [] } }
        else
          return Array(submitted_teams).map { |t| { name: t[:name], player_ids: t[:player_ids] || [] } }
        end
      end

      baseline_teams = match_day.teams.where(team_type: "baseline").order(:created_at)
      if baseline_teams.any?
        baseline_teams.map { |t| { name: t.name, player_ids: t.player_ids.map(&:to_s) } }
      else
        [
          { name: "Team A", player_ids: [] },
          { name: "Team B", player_ids: [] }
        ]
      end
    end
  end
end
