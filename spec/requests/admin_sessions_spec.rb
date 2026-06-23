require "rails_helper"

RSpec.describe "Admin sessions" do
  describe "GET /admin/login" do
    context "when a visitor opens the login page" do
      it "renders the password form" do
        get "/admin/login"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Zaloguj")
        expect(response.body).to include("Hasło")
      end
    end
  end

  describe "POST /admin/session" do
    context "when the password is valid" do
      it "signs in the admin" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          Rails.application.routes.draw do
            get "/admin/protected_test", to: "admin/protected_test#index"
            get "/admin/login", to: "admin/sessions#new", as: :admin_login
            resource :admin_session, path: "/admin/session", only: %i[create destroy], controller: "admin/sessions"
            root "home#index"
          end

          stub_const(
            "Admin::ProtectedTestController",
            Class.new(ApplicationController) do
              before_action :require_admin!

              def index
                render plain: admin_signed_in?.to_s
              end
            end
          )

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/protected_test"

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq("true")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end

          Rails.application.reload_routes!
        end
      end
    end

    context "when the password is invalid" do
      it "rejects the login" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          post "/admin/session", params: { password: "wrong-password" }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Invalid admin password")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when no admin password is configured" do
      it "rejects the login" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")

          post "/admin/session", params: { password: "secret-password" }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Invalid admin password")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end
  end

  describe "DELETE /admin/session" do
    context "when the visitor is signed in as admin" do
      it "signs out the admin" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          Rails.application.routes.draw do
            get "/admin/protected_test", to: "admin/protected_test#index"
            get "/admin/login", to: "admin/sessions#new", as: :admin_login
            resource :admin_session, path: "/admin/session", only: %i[create destroy], controller: "admin/sessions"
            root "home#index"
          end

          stub_const(
            "Admin::ProtectedTestController",
            Class.new(ApplicationController) do
              before_action :require_admin!

              def index
                render plain: admin_signed_in?.to_s
              end
            end
          )

          post "/admin/session", params: { password: "secret-password" }
          delete "/admin/session"
          get "/admin/protected_test"

          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("Admin access required")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end

          Rails.application.reload_routes!
        end
      end
    end
  end
end
