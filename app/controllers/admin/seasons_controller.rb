module Admin
  class SeasonsController < ApplicationController
    before_action :require_admin!

    def index
      seasons = Season.order(starts_on: :desc, name: :asc)

      render :index, locals: { seasons: seasons }
    end

    def new
      season = Season.new

      render :new, locals: { season: season }
    end

    def create
      season = Season.new(season_params)

      if season.save
        redirect_to admin_seasons_path, notice: "Season created"
      else
        render :new, locals: { season: season }, status: :unprocessable_content
      end
    end

    def edit
      season = Season.find(params[:id])

      render :edit, locals: { season: season }
    end

    def update
      season = Season.find(params[:id])

      if season.update(season_params)
        redirect_to admin_seasons_path, notice: "Season updated"
      else
        render :edit, locals: { season: season }, status: :unprocessable_content
      end
    end

    def destroy
      season = Season.find(params[:id])
      season.destroy!

      redirect_to admin_seasons_path, notice: "Season deleted"
    end

    private

    def season_params
      params
        .require(:season)
        .permit(:name, :starts_on, :ends_on, :active, :initial_elo, :elo_k_factor, :mvp_vote_bonus, :def_vote_bonus)
    end
  end
end
