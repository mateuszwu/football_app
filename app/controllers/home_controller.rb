class HomeController < ApplicationController
  def index
    dashboard = Dashboard::TilesQuery.call(admin_signed_in: admin_signed_in?)

    render :index, locals: { dashboard: }
  end
end
