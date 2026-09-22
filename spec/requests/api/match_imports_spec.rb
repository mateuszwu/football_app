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
            all_roster_players_on_pitch: true,
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
                all_roster_players_on_pitch: false,
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
              "score" => { "home" => 1, "away" => 0 },
              "all_roster_players_on_pitch" => true
            },
            {
              "match_id" => matches.second.id,
              "match_url" => match_url(matches.second),
              "status" => "in_progress",
              "score" => { "home" => 0, "away" => 1 },
              "all_roster_players_on_pitch" => false
            }
          )
          expect(matches.first.match_day.season).to eq(season)
          expect(matches.first).to be_all_roster_players_on_pitch
          expect(matches.second).not_to be_all_roster_players_on_pitch
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

      it "imports player changes and keeps goals valid before and after a team switch" do
        begin
          original_api_token = ENV["FOOTBALL_APP_API_TOKEN"]
          ENV["FOOTBALL_APP_API_TOKEN"] = "secret-token"
          season = create(:season)
          create(:player, name: "Switching Player", nickname: "switching", approval_status: "approved", active: true)
          create(:player, name: "Home Player", nickname: "home-player", approval_status: "approved", active: true)
          create(:player, name: "Away Player", nickname: "away-player", approval_status: "approved", active: true)
          create(:player, name: "Leaving Player", nickname: "leaving", approval_status: "approved", active: true)
          headers = { "Authorization" => "Bearer secret-token" }
          payload = {
            season_id: season.id,
            played_on: "2026-06-19",
            original_teams: [
              { name: "Original A", players: [ "switching", "home-player", "leaving" ] },
              { name: "Original B", players: [ "away-player" ] }
            ],
            matches: [
              {
                started_at: "2026-06-19 19:00",
                finished_at: "2026-06-19 19:30",
                teams: [
                  { name: "Team A", players: [ "switching", "home-player", "leaving" ] },
                  { name: "Team B", players: [ "away-player" ] }
                ],
                player_changes: [
                  { player: "switching", from_team: "Team A", to_team: "Team B", occurred_at: "2026-06-19 19:10" },
                  { player: "leaving", from_team: "Team A", to_team: nil, occurred_at: "2026-06-19 19:20" }
                ],
                goals: [
                  { team: "Team A", scorer: "switching", scored_at: "2026-06-19 19:05" },
                  { team: "Team B", scorer: "switching", assistant: "away-player", scored_at: "2026-06-19 19:15" }
                ]
              }
            ]
          }

          post "/api/match_imports", params: payload, headers:, as: :json

          match = Match.order(:id).last
          changes = match.match_player_changes.order(:occurred_at)
          goals = match.match_goals.order(:scored_at)

          expect(response).to have_http_status(:created)
          expect(response.parsed_body["matches"].first["player_changes"]).to eq([
            {
              "player" => "switching",
              "from_team" => "Team A",
              "to_team" => "Team B",
              "event_type" => "team_change",
              "occurred_at" => "2026-06-19T19:10:00Z"
            },
            {
              "player" => "leaving",
              "from_team" => "Team A",
              "to_team" => nil,
              "event_type" => "substitution_out",
              "occurred_at" => "2026-06-19T19:20:00Z"
            }
          ])
          expect(changes.map(&:event_type)).to eq([ "team_change", "substitution_out" ])
          expect(goals.map { |goal| [ goal.scorer.nickname, goal.scoring_team.name ] }).to eq(
            [ [ "switching", "Team A" ], [ "switching", "Team B" ] ]
          )
          expect(match.final_players_for(match.home_team).map(&:nickname)).to contain_exactly("home-player")
          expect(match.final_players_for(match.away_team).map(&:nickname)).to contain_exactly("switching", "away-player")
          expect(match.home_team.team_players.find_by!(player: Player.find_by!(nickname: "switching")).elo_delta).to be_nil
          expect(match.away_team.team_players.find_by!(player: Player.find_by!(nickname: "switching")).elo_delta).to be_present
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
