require "rails_helper"

RSpec.describe "API match imports" do
  describe "POST /api/match_imports" do
    context "when the bearer token is valid" do
      it "creates multiple matches from JSON and returns the created records" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          season = create(:season)
          create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
          create(:player, name: "Jan Kowalski", nickname: "jan", phone: "+48222222222", approval_status: "approved", active: true)
          create(:player, name: "Marek Wisniewski", nickname: "marek", phone: "+48333333333", approval_status: "approved", active: true)
          headers = { "Authorization" => "Bearer secret-token" }
          payload = {
            season_id: season.id,
            played_on: "2026-06-19",
            original_teams: [
              { name: "Original A", players: [ "adam", "jan" ], captain: "adam" },
              { name: "Original B", players: [ "marek" ], captain: "marek" }
            ],
            matches: [
              {
                started_at: "2026-06-19 19:00",
                finished_at: "2026-06-19 19:30",
                teams: [
                  { name: "Team A", players: [ "adam" ], captain: "adam" },
                  { name: "Team B", players: [ "jan" ], captain: "jan" }
                ],
                goals: [
                  { team: "Team A", scorer: "adam", scored_at: "2026-06-19 19:12:34" }
                ]
              },
              {
                started_at: "2026-06-19 19:35",
                teams: [
                  { name: "Team A", players: [ "adam", "marek" ], captain: "marek" },
                  { name: "Team B", players: [ "jan" ], captain: "jan" }
                ],
                goals: [
                  { team: "Team B", scorer: "jan" }
                ]
              }
            ]
          }

          post "/api/match_imports", params: payload, headers:, as: :json

          matches = Match.order(:id).last(2)
          expect(response).to have_http_status(:created)
          expect(response.parsed_body).to include(
            "match_day_id" => matches.first.match_day_id,
            "status" => "in_progress"
          )
          expect(response.parsed_body["matches"]).to contain_exactly(
            {
              "match_id" => matches.first.id,
              "match_url" => match_url(matches.first),
              "status" => "finished",
              "score" => { "home" => 1, "away" => 0 }
            },
            {
              "match_id" => matches.second.id,
              "match_url" => match_url(matches.second),
              "status" => "in_progress",
              "score" => { "home" => 0, "away" => 1 }
            }
          )
          expect(matches.first.match_day.season).to eq(season)
          expect(matches.first.home_team.players.map(&:nickname)).to eq([ "adam" ])
          expect(matches.first.away_team.players.map(&:nickname)).to eq([ "jan" ])
          expect(matches.first.home_team.captain.nickname).to eq("adam")
          expect(matches.first.away_team.captain.nickname).to eq("jan")
          expect(matches.first.match_goals.first.scored_at).to eq(Time.zone.parse("2026-06-19 19:12:34"))
          expect(matches.second.home_team.players.map(&:nickname)).to contain_exactly("adam", "marek")
          expect(matches.second.away_team.players.map(&:nickname)).to eq([ "jan" ])
          expect(matches.second.home_team.captain.nickname).to eq("marek")
          expect(matches.second.away_team.captain.nickname).to eq("jan")
        ensure
          if original_api_token.nil?
            ENV.delete("FOOTBALL_APP_API_TOKEN")
          else
            ENV["FOOTBALL_APP_API_TOKEN"] = original_api_token
          end
        end
      end

      it "returns validation errors without creating a match" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          season = create(:season)
          headers = { "Authorization" => "Bearer secret-token" }
          payload = {
            season_id: season.id,
            played_on: "2026-06-19",
            original_teams: [
              { name: "Original A", players: [ "ghost" ] },
              { name: "Original B", players: [ "another" ] }
            ],
            matches: [
              {
                teams: [
                  { name: "Team A", players: [ "ghost" ] },
                  { name: "Team B", players: [ "another" ] }
                ],
                goals: [
                  { team: "Team A", scorer: "ghost" }
                ]
              }
            ]
          }

          post "/api/match_imports", params: payload, headers:, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["errors"]).to include("Unknown approved active player: ghost")
          expect(Match.count).to eq(0)
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

          post "/api/match_imports", params: {}, as: :json

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
