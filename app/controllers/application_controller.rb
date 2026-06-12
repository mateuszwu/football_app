class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :admin_authenticated?
  helper_method :admin_signed_in?
  helper_method :current_season

  private

  def current_season
    Season.current_active
  end

  def admin_authenticated?
    session[:admin_authenticated] == true || session[:admin] == true
  end

  def admin_signed_in?
    admin_authenticated?
  end

  def require_admin!
    return if admin_authenticated?

    redirect_to root_path, alert: "Admin access required"
  end
end
