module Admin
  class SessionsController < ApplicationController
    def new
    end

    def create
      if valid_admin_password?
        session[:admin_authenticated] = true
        session[:admin] = true
        redirect_to root_path, notice: "Signed in as admin"
      else
        session[:admin_authenticated] = false
        session[:admin] = false
        flash.now[:alert] = "Invalid admin password"
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      session[:admin_authenticated] = false
      session[:admin] = false
      redirect_to root_path, notice: "Signed out"
    end

    private

    def valid_admin_password?
      expected_password = admin_password
      submitted_password = params[:password].to_s

      return false if expected_password.blank? || submitted_password.blank?

      ActiveSupport::SecurityUtils.secure_compare(submitted_password, expected_password)
    end

    def admin_password
      Rails.application.credentials.dig(:admin, :password).presence ||
        Rails.application.credentials.admin_password.presence ||
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"].presence
    end
  end
end
