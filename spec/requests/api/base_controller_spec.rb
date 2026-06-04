require "rails_helper"

RSpec.describe "API base controller" do
  describe "GET /api/protected_test" do
    context "when the bearer token is valid" do
      it "allows the request" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }

          Rails.application.routes.draw do
            get "/api/protected_test", to: "api/protected_test#index"
          end

          stub_const(
            "Api::ProtectedTestController",
            Class.new(Api::BaseController) do
              def index
                render json: { ok: true }
              end
            end
          )

          get "/api/protected_test", headers: headers

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq("ok" => true)
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end

          Rails.application.reload_routes!
        end
      end
    end

    context "when the bearer token is missing" do
      it "rejects the request" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"

          Rails.application.routes.draw do
            get "/api/protected_test", to: "api/protected_test#index"
          end

          stub_const(
            "Api::ProtectedTestController",
            Class.new(Api::BaseController) do
              def index
                render json: { ok: true }
              end
            end
          )

          get "/api/protected_test"

          expect(response).to have_http_status(:unauthorized)
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end

          Rails.application.reload_routes!
        end
      end
    end

    context "when the bearer token is invalid" do
      it "rejects the request" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer wrong-token" }

          Rails.application.routes.draw do
            get "/api/protected_test", to: "api/protected_test#index"
          end

          stub_const(
            "Api::ProtectedTestController",
            Class.new(Api::BaseController) do
              def index
                render json: { ok: true }
              end
            end
          )

          get "/api/protected_test", headers: headers

          expect(response).to have_http_status(:unauthorized)
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end

          Rails.application.reload_routes!
        end
      end
    end

    context "when no API token is configured" do
      it "rejects the request" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV.delete("FOOTBALL_APP_API_TOKEN")
          headers = { "Authorization" => "Bearer secret-token" }

          Rails.application.routes.draw do
            get "/api/protected_test", to: "api/protected_test#index"
          end

          stub_const(
            "Api::ProtectedTestController",
            Class.new(Api::BaseController) do
              def index
                render json: { ok: true }
              end
            end
          )

          get "/api/protected_test", headers: headers

          expect(response).to have_http_status(:unauthorized)
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end

          Rails.application.reload_routes!
        end
      end
    end
  end
end
