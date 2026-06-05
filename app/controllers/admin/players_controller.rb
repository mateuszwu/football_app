module Admin
  class PlayersController < ApplicationController
    before_action :require_admin!

    def index
      @players = Player.order(:name)
    end
  end
end
