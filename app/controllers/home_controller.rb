class HomeController < ApplicationController
  def index
    current_season = Season.current_active
    players = Player.approved.active.order(:name)

    render :index, locals: { current_season: current_season, players: players }
  end
end
