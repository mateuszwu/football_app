class HomeController < ApplicationController
  def index
    dashboard = Rails.cache.fetch([ "dashboard", "v2", admin_signed_in? ? "admin" : "public", PublicStats::CacheKey.global ], expires_in: 5.minutes) do
      Dashboard::TilesQuery.call(admin_signed_in: admin_signed_in?)
    end

    render :index, locals: { dashboard: }
  end
end
