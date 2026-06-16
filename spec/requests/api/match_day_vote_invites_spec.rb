require "rails_helper"

RSpec.describe "API match day vote invites" do
  describe "GET /api/match_days/:id/vote_invites" do
    context "when the bearer token is valid" do
      it "returns phones and individual vote links for the match day players" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          match_day = create(:match_day)
          adam = create(:player, name: "Adam", nickname: "adam", phone: "+48222222222", active: true)
          zed = create(:player, name: "Zed", nickname: "zed", phone: "+48111111111", active: true)
          adam_match_day_player = create(:match_day_player, match_day:, player: adam)
          zed_match_day_player = create(:match_day_player, match_day:, player: zed)

          get "/api/match_days/#{match_day.id}/vote_invites", headers: headers

          expect(response).to have_http_status(:ok)
          expect(adam_match_day_player.reload.match_day_vote_token).to be_present
          expect(zed_match_day_player.reload.match_day_vote_token).to be_present
          expect(response.parsed_body).to eq(
            "vote_invites" => [
              {
                "name" => "Adam",
                "phone" => "+48222222222",
                "sms_body" => "Czesc Adam, zaglosuj na MVP i DEF: http://www.example.com/votes/#{adam_match_day_player.match_day_vote_token.token}"
              },
              {
                "name" => "Zed",
                "phone" => "+48111111111",
                "sms_body" => "Czesc Zed, zaglosuj na MVP i DEF: http://www.example.com/votes/#{zed_match_day_player.match_day_vote_token.token}"
              }
            ]
          )
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end

      it "keeps existing vote tokens" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          match_day = create(:match_day)
          player = create(:player, name: "Adam", nickname: "adam", phone: "+48222222222", active: true)
          match_day_player = create(:match_day_player, match_day:, player:)
          existing_token = create(:match_day_vote_token, match_day_player:, token: "existing-token")

          get "/api/match_days/#{match_day.id}/vote_invites", headers: headers

          expect(response).to have_http_status(:ok)
          expect(match_day_player.reload.match_day_vote_token).to eq(existing_token)
          expect(response.parsed_body.dig("vote_invites", 0, "sms_body")).to include("/votes/existing-token")
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
          match_day = create(:match_day)

          get "/api/match_days/#{match_day.id}/vote_invites"

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
