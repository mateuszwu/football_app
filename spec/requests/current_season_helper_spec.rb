require "rails_helper"

RSpec.describe "Current season helper" do
  describe "GET /current_season_test" do
    context "when there is an active season" do
      it "returns the current active season name" do
        begin
          Rails.application.routes.draw do
            get "/current_season_test", to: "current_season_test#index"
          end

          stub_const(
            "CurrentSeasonTestController",
            Class.new(ApplicationController) do
              def index
                render plain: current_season&.name || "none"
              end
            end
          )

          create(:season, name: "Spring 2026", status: Season::STATUS_ARCHIVED)
          create(:season, name: "Summer 2026", status: Season::STATUS_ACTIVE, starts_on: Date.new(2026, 6, 1))

          get "/current_season_test"

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq("Summer 2026")
        ensure
          Rails.application.reload_routes!
        end
      end
    end

    context "when there is no active season" do
      it "returns none" do
        begin
          Rails.application.routes.draw do
            get "/current_season_test", to: "current_season_test#index"
          end

          stub_const(
            "CurrentSeasonTestController",
            Class.new(ApplicationController) do
              def index
                render plain: current_season&.name || "none"
              end
            end
          )

          create(:season, name: "Spring 2026", status: Season::STATUS_ARCHIVED)

          get "/current_season_test"

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq("none")
        ensure
          Rails.application.reload_routes!
        end
      end
    end
  end
end
