require "rails_helper"

RSpec.describe "Matches" do
  describe "GET /matches/:id" do
    context "when the match has teams and players" do
      it "renders the live match screen without phone data" do
        travel_to Time.zone.parse("2026-06-19 19:49:30") do
          season = create(:season, name: "Summer 2026")
          match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 19), status: "in_progress")
          team_setup = create(:team_setup, match_day: match_day)
          home_team = create(:team, team_setup: team_setup, name: "Team A", team_type: "match")
          away_team = create(:team, team_setup: team_setup, name: "Team B", team_type: "match")
          home_player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111")
          away_player = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222")
          create(:team_player, team: home_team, player: home_player)
          create(:team_player, team: away_team, player: away_player)
          match = create(
            :match,
            match_day: match_day,
            home_team: home_team,
            away_team: away_team,
            home_score: 2,
            away_score: 1,
            started_at: Time.zone.parse("2026-06-19 19:15:00")
          )

          get "/matches/#{match.id}"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Live match")
          expect(response.body).to include("Team A vs Team B")
          expect(response.body).to include("Summer 2026")
          expect(response.body).to include("2026-06-19")
          expect(response.body).to include("Home")
          expect(response.body).to include("Away")
          expect(response.body).to include("2")
          expect(response.body).to include("1")
          expect(response.body).to include("in_progress")
          expect(response.body).to include("Started at 19:15")
          expect(response.body).to include("Match timer")
          expect(response.body).to include("34:30")
          expect(response.body).to include("Team A lineup")
          expect(response.body).to include("Team B lineup")
          expect(response.body).to include("Adam Nowak")
          expect(response.body).to include("adam")
          expect(response.body).to include("Marek Kowalski")
          expect(response.body).to include("marek")
          expect(response.body).not_to include("+48111111111")
          expect(response.body).not_to include("+48222222222")
          expect(response.body).not_to include("phone")
        end
      end

      it "renders scored goals on the match scoreboard" do
        season = create(:season, name: "Summer 2026")
        match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 19), status: "in_progress")
        team_setup = create(:team_setup, match_day: match_day)
        home_team = create(:team, team_setup: team_setup, name: "Team A", team_type: "match")
        away_team = create(:team, team_setup: team_setup, name: "Team B", team_type: "match")
        home_player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111")
        away_player = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222")
        create(:team_player, team: home_team, player: home_player)
        create(:team_player, team: away_team, player: away_player)
        match = create(
          :match,
          match_day: match_day,
          home_team: home_team,
          away_team: away_team,
          home_score: 1,
          away_score: 0,
          started_at: Time.zone.parse("2026-06-19 19:15:00")
        )
        create(
          :match_goal,
          match: match,
          scoring_team: home_team,
          scorer: home_player,
          scored_at: Time.zone.parse("2026-06-19 19:27:00")
        )

        get "/matches/#{match.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("adam")
        expect(response.body).to include("(12&#39;)")
      end

      it "shows admin goal forms only for admins" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match = create(:match, started_at: Time.zone.parse("2026-06-19 19:15:00"))
          home_player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111")
          away_player = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222")
          create(:team_player, team: match.home_team, player: home_player)
          create(:team_player, team: match.away_team, player: away_player)

          get "/matches/#{match.id}"

          expect(response.body).not_to include("Add goal")

          post "/admin/session", params: { password: "secret-password" }
          get "/matches/#{match.id}"

          expect(response.body).to include("Add goal")
          expect(response.body).to include("Add goal for #{match.home_team.name}")
          expect(response.body).to include("Add goal for #{match.away_team.name}")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when the match has not started and no players are assigned" do
      it "renders empty lineup states" do
        match = create(:match, started_at: nil)

        get "/matches/#{match.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("not_started")
        expect(response.body).to include("Kick-off not started yet.")
        expect(response.body).to include("Match timer")
        expect(response.body).to include("00:00")
        expect(response.body).to include("No players assigned yet.")
      end
    end

    context "when the match is finished" do
      it "renders the final timer value" do
        match = create(
          :match,
          started_at: Time.zone.parse("2026-06-19 19:15:00"),
          finished_at: Time.zone.parse("2026-06-19 20:02:10")
        )

        get "/matches/#{match.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("finished")
        expect(response.body).to include("Match timer")
        expect(response.body).to include("47:10")
      end
    end
  end
end
