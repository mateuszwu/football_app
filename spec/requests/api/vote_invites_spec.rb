require "rails_helper"

RSpec.describe "API vote invites" do
  describe "GET /api/vote_invites" do
    context "when the bearer token is valid" do
      it "returns active player phone numbers and SMS bodies" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          headers = { "Authorization" => "Bearer secret-token" }
          create(:player, name: "Zed", nickname: "zed", phone: "+48111111111", active: true)
          create(:player, name: "Adam", nickname: "adam", phone: "+48222222222", active: true)
          create(:player, name: "Inactive", nickname: "inactive", phone: "+48333333333", active: false)

          get "/api/vote_invites", headers: headers

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(
            "vote_invites" => [
              {
                "phone" => "+48222222222",
                "sms_body" => "Czesc adam, zaglosuj na MVP i DEF po dzisiejszym meczu."
              },
              {
                "phone" => "+48111111111",
                "sms_body" => "Czesc zed, zaglosuj na MVP i DEF po dzisiejszym meczu."
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
    end
  end
end
