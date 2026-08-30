require "rails_helper"

RSpec.describe "API players" do
  describe "GET /api/players" do
    context "when the bearer token is valid" do
      it "returns the player catalog ordered by name" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          first_player = create(:player, name: "Adam API", nickname: "adam-api", approval_status: "approved", active: true)
          second_player = create(:player, name: "Zosia API", nickname: "zosia-api", approval_status: "pending", active: false)
          headers = { "Authorization" => "Bearer secret-token" }

          get "/api/players", headers:, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to include("count" => 2)
          expect(response.parsed_body["players"].map { |player| player["id"] }).to eq([ first_player.id, second_player.id ])
          expect(response.parsed_body["players"].first).to include(
            "name" => "Adam API",
            "nickname" => "adam-api",
            "approval_status" => "approved",
            "active" => true
          )
          expect(response.body).not_to include(first_player.phone.to_s)
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end

      it "filters the catalog by search and public visibility" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          matching_player = create(:player, name: "Piotrek (Nowy)", nickname: "piotrek-nowy", approval_status: "approved", active: true)
          create(:player, name: "Piotr Bramkarz", nickname: "piotr-bramkarz", approval_status: "approved", active: true)
          create(:player, name: "Piotrek Pending", nickname: "piotrek-pending", approval_status: "pending", active: true)
          headers = { "Authorization" => "Bearer secret-token" }

          get "/api/players", params: { search: "NOWY", approval_status: "approved", active: true }, headers:, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to include("count" => 1)
          expect(response.parsed_body["players"].first["id"]).to eq(matching_player.id)
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

          get "/api/players", as: :json

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

  describe "POST /api/players" do
    context "when the bearer token is valid" do
      it "creates a player from JSON and assigns missing identity" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          payload = {
            player: {
              name: "Adam API",
              nickname: "adam-api",
              phone: "+48100100200",
              description: "Zawodnik dodany przez API",
              role_code: "MID",
              approval_status: "approved",
              active: true
            }
          }

          post "/api/players", params: payload, headers:, as: :json

          player = Player.find_by!(nickname: "adam-api")
          expect(response).to have_http_status(:created)
          expect(response.parsed_body).to include(
            "id" => player.id,
            "name" => "Adam API",
            "nickname" => "adam-api",
            "description" => "Zawodnik dodany przez API",
            "role_code" => "MID",
            "approval_status" => "approved",
            "active" => true,
            "profile_color_key" => player.profile_color_key,
            "profile_color_hex" => player.profile_color_hex,
            "profile_icon" => player.profile_icon
          )
          expect(response.parsed_body).not_to include("phone")
          expect(player.phone).to eq("+48100100200")
          expect(player.profile_icon).to be_present
          expect(player.profile_color_key).to be_present
          expect(player.profile_color_hex).to be_present
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end

      it "returns validation errors without creating a player" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          payload = {
            name: "",
            nickname: "",
            description: "Missing required identity"
          }

          post "/api/players", params: payload, headers:, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.fetch("errors")).to include("name", "nickname")
          expect(Player.where(description: "Missing required identity")).to be_empty
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

          post "/api/players", params: { name: "Adam API" }, as: :json

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
