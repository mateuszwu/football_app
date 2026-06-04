require "rails_helper"

RSpec.describe "API vote invites" do
  describe "GET /api/vote_invites" do
    context "when the bearer token is valid" do
      it "returns the vote invites collection" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }

          get "/api/vote_invites", headers: headers

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq("vote_invites" => [])
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end

      it "returns phone and sms_body when an invite is provided" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          params = {
            phone: "+48123456789",
            sms_body: "Vote for this match"
          }

          get "/api/vote_invites", params: params, headers: headers

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(
            "vote_invites" => [
              {
                "phone" => "+48123456789",
                "sms_body" => "Vote for this match"
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
    end

    context "when the bearer token is missing" do
      it "rejects the request" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"

          get "/api/vote_invites"

          expect(response).to have_http_status(:unauthorized)
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end

      it "does not expose phone or sms_body" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          params = {
            phone: "+48123456789",
            sms_body: "Vote for this match"
          }

          get "/api/vote_invites", params: params

          expect(response).to have_http_status(:unauthorized)
          expect(response.body).not_to include("+48123456789")
          expect(response.body).not_to include("Vote for this match")
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
