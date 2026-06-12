require "rails_helper"

RSpec.describe "Admin access" do
  describe "GET /admin/protected_test" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        begin
          Rails.application.routes.draw do
            get "/admin/protected_test", to: "admin/protected_test#index"
            root "home#index"
          end

          stub_const(
            "Admin::ProtectedTestController",
            Class.new(ApplicationController) do
              before_action :require_admin!

              def index
                render plain: "admin"
              end
            end
          )

          get "/admin/protected_test"

          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("Admin access required")
        ensure
          Rails.application.reload_routes!
        end
      end
    end

    context "when the visitor is signed in as admin" do
      it "allows the request" do
        begin
          Rails.application.routes.draw do
            get "/admin/sign_in_test", to: "admin/sign_in_test#create"
            get "/admin/protected_test", to: "admin/protected_test#index"
            root "home#index"
          end

          stub_const(
            "Admin::SignInTestController",
            Class.new(ApplicationController) do
              def create
                session[:admin] = true
                head :no_content
              end
            end
          )

          stub_const(
            "Admin::ProtectedTestController",
            Class.new(ApplicationController) do
              before_action :require_admin!

              def index
                render plain: admin_signed_in?.to_s
              end
            end
          )

          get "/admin/sign_in_test"
          get "/admin/protected_test"

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq("true")
        ensure
          Rails.application.reload_routes!
        end
      end
    end
  end
end
