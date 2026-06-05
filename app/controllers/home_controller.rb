class HomeController < ApplicationController
  def index
    players = Player.approved.active.order(:name)

    render :index, locals: { players: players }
  end
end
