require "rails_helper"

RSpec.describe "API seasons" do
  describe "POST /api/seasons" do
    context "when the bearer token is valid" do
      it "creates a season from JSON" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          payload = {
            season: {
              name: "Jesien 2026",
              starts_on: "2026-09-01",
              ends_on: "2026-11-30",
              status: "active",
              initial_elo: 1000,
              elo_k_factor: 24,
              elo_k_value: "24.0",
              player_advantage_elo: "40.0",
              season_elo_carryover_factor: "0.5",
              goal_points: "1.0",
              assist_points: "0.8",
              mvp_max_points: "4.0",
              def_max_points: "3.0",
              voting_bonus_cap: "5.0",
              expected_voters_count: 10,
              mvp_vote_bonus: 10,
              def_vote_bonus: 10
            }
          }

          post "/api/seasons", params: payload, headers:, as: :json

          season = Season.find_by!(name: "Jesien 2026")
          expect(response).to have_http_status(:created)
          expect(response.parsed_body).to include(
            "id" => season.id,
            "name" => "Jesien 2026",
            "starts_on" => "2026-09-01",
            "ends_on" => "2026-11-30",
            "status" => "active",
            "initial_elo" => 1000,
            "elo_k_factor" => 24,
            "elo_k_value" => "24.0"
          )
          expect(season).to have_attributes(
            elo_k_value: BigDecimal("24.0"),
            goal_points: BigDecimal("1.0"),
            assist_points: BigDecimal("0.8")
          )
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end

      it "returns validation errors without creating a season" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          payload = {
            name: "",
            starts_on: "2026-09-01",
            status: "invalid"
          }

          post "/api/seasons", params: payload, headers:, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.fetch("errors")).to include("name", "status")
          expect(Season.where(starts_on: Date.new(2026, 9, 1))).to be_empty
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end
    end

    context "when the bearer token is missing" do
      it "rejects the request" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"

          post "/api/seasons", params: { name: "Jesien 2026" }, as: :json

          expect(response).to have_http_status(:unauthorized)
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end
    end
  end
end
