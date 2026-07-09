require "rails_helper"

RSpec.describe "Matches" do
  describe "GET /matches/:id" do
    context "when the match has teams and players" do
      it "renders the match summary without phone data or live-screen copy" do
        travel_to Time.zone.parse("2026-06-19 19:49:30") do
          season = create(:season, name: "Summer 2026")
          match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 19), status: "in_progress")
          team_setup = create(:team_setup, match_day: match_day)
          home_team = create(:team, team_setup: team_setup, name: "Team A", team_type: "match")
          away_team = create(:team, team_setup: team_setup, name: "Team B", team_type: "match")
          home_player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111")
          home_player.update_columns(profile_icon: "sun", profile_color_key: "red_dark", profile_color_hex: "#B91C1C")
          away_player = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222")
          create(:team_player, team: home_team, player: home_player, position: 1)
          create(:team_player, team: away_team, player: away_player)
          home_team.update!(captain: home_player)
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
          expect(response.body).to include('<body class="theme-dark public-layout">')
          expect(response.body).to include("Football App")
          expect(response.body).to include("Weekendowe granie")
          expect(response.body).to include("MECZ")
          expect(response.body).to include("Team A vs Team B")
          expect(response.body).to include("Summer 2026")
          expect(response.body).to include("2026-06-19")
          expect(response.body).not_to include("Gospodarze")
          expect(response.body).not_to include("Goście")
          expect(response.body).to include("2")
          expect(response.body).to include("1")
          expect(response.body).to include("W trakcie")
          expect(response.body).to include("Start")
          expect(response.body).to include("19:15")
          expect(response.body).to include("Czas meczu")
          expect(response.body).to include("34:30")
          expect(response.body).to include("Składy i wkład zawodników")
          expect(response.body).to include(">SAM</span>")
          expect(response.body).not_to include(">SG</span>")
          expect(response.body).to include("Adam Nowak")
          expect(response.body).to include("Marek Kowalski")
          expect(response.body).to include("lucide-sun")
          expect(response.body).to include("--captain-color: #B91C1C")
          expect(response.body).to include("Kapitan")
          expect(response.body).not_to include("Mecz live")
          expect(response.body).not_to include("Ostatnie wydarzenia")
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
        home_team_player = create(:team_player, team: home_team, player: home_player)
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
          scorer_team_player: home_team_player,
          scored_at: Time.zone.parse("2026-06-19 19:27:00")
        )

        get "/matches/#{match.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("13&#39;")
        expect(response.body).to include("1 : 0")
      end

      it "renders the chronological timeline with assists and score progression" do
        season = create(:season, name: "Summer 2026")
        match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 19), status: "in_progress")
        team_setup = create(:team_setup, match_day: match_day)
        home_team = create(:team, team_setup: team_setup, name: "Team A", team_type: "match")
        away_team = create(:team, team_setup: team_setup, name: "Team B", team_type: "match")
        home_player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111")
        home_player2 = create(:player, name: "Jan Kowalski", nickname: "jan", phone: "+48333333333")
        away_player = create(:player, name: "Marek Wisniewski", nickname: "marek", phone: "+48222222222")
        home_team_player = create(:team_player, team: home_team, player: home_player)
        home_team_player2 = create(:team_player, team: home_team, player: home_player2)
        create(:team_player, team: away_team, player: away_player)
        match = create(
          :match,
          match_day: match_day,
          home_team: home_team,
          away_team: away_team,
          home_score: 2,
          away_score: 0,
          started_at: Time.zone.parse("2026-06-19 19:15:00")
        )
        create(
          :match_goal,
          match: match,
          scoring_team: home_team,
          scorer_team_player: home_team_player,
          assistant_team_player: home_team_player2,
          scored_at: Time.zone.parse("2026-06-19 19:27:00")
        )
        create(
          :match_goal,
          match: match,
          scoring_team: home_team,
          scorer_team_player: home_team_player2,
          scored_at: Time.zone.parse("2026-06-19 19:40:00")
        )

        get "/matches/#{match.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Przebieg meczu")
        expect(response.body).to include("Team A")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("13. minuta")
        expect(response.body).to include("26. minuta")
        expect(response.body).to include("asysta: Jan Kowalski")
        expect(response.body).to include("0:0 → 1:0 → 2:0")
        expect(response.body).to include("2 : 0")
        expect(response.body).not_to include("Ostatnie wydarzenia")
      end

      it "renders own goals as match summary data" do
        season = create(:season, name: "Summer 2026")
        match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 19), status: "finished")
        team_setup = create(:team_setup, match_day: match_day)
        home_team = create(:team, team_setup: team_setup, name: "Team A", team_type: "match")
        away_team = create(:team, team_setup: team_setup, name: "Team B", team_type: "match")
        away_player = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222")
        create(:team_player, team: home_team, player: create(:player, name: "Adam Nowak", nickname: "adam"))
        away_team_player = create(:team_player, team: away_team, player: away_player)
        match = create(
          :match,
          match_day: match_day,
          home_team: home_team,
          away_team: away_team,
          home_score: 1,
          away_score: 0,
          started_at: Time.zone.parse("2026-06-19 19:15:00"),
          finished_at: Time.zone.parse("2026-06-19 19:45:00")
        )
        create(
          :match_goal,
          match: match,
          scoring_team: home_team,
          scorer_team_player: away_team_player,
          own_goal: true,
          scored_at: Time.zone.parse("2026-06-19 19:27:00"),
          home_score_after: 1,
          away_score_after: 0
        )

        get "/matches/#{match.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Samobóje")
        expect(response.body).to include("samobój: Marek Kowalski")
        expect(response.body).to include("SAMOBÓJ")
        expect(response.body).to include("dla: Team A")
        expect(response.body).not_to include("+48222222222")
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
          expect(response.body).not_to include("Finish match")

          post "/admin/session", params: { password: "secret-password" }
          get "/matches/#{match.id}"

          expect(response.body).to include("Finish match")
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
        expect(response.body).to include("Nierozpoczęty")
        expect(response.body).to include("Brak zdarzeń bramkowych w tym meczu.")
        expect(response.body).to include("Czas meczu")
        expect(response.body).to include("00:00")
        expect(response.body).to include("Brak przypisanych zawodników.")
      end

      it "shows the pre-match lineup editor only for admins" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match_day = create(:match_day)
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, match: nil, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, match: nil, name: "Team B", team_type: Team::TEAM_TYPE_MATCH)
          create(:team_player, team: home_team, player: create(:player, name: "Adam", nickname: "adam"))
          create(:team_player, team: away_team, player: create(:player, name: "Marek", nickname: "marek", phone: "+48999999998"))
          match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
          home_team.update!(match:)
          away_team.update!(match:)

          get "/matches/#{match.id}"

          expect(response.body).not_to include("Pre-match lineup editor")
          expect(response.body).not_to include("Start match")

          post "/admin/session", params: { password: "secret-password" }
          get "/matches/#{match.id}"

          expect(response.body).to include("Pre-match lineup editor")
          expect(response.body).to include("Reset to baseline")
          expect(response.body).to include("Copy previous match")
          expect(response.body).to include("Start match")
          expect(response.body).to include("Save lineup")
          expect(response.body).to include("Add team")
          expect(response.body).to include("data-lineup-editor-input-name-prefix-value=\"match[teams_data]\"")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when the match is Zakończony" do
      it "renders the final timer value" do
        match = create(
          :match,
          started_at: Time.zone.parse("2026-06-19 19:15:00"),
          finished_at: Time.zone.parse("2026-06-19 20:02:10")
        )

        get "/matches/#{match.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Zakończony")
        expect(response.body).to include("Czas meczu")
        expect(response.body).to include("47:10")
        expect(response.body).to include("Zobacz mecze dnia")
        expect(response.body).to include("/match_days/#{match.match_day_id}")
      end

      it "shows admin correction controls for signed-in admins" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match = create(
            :match,
            started_at: Time.zone.parse("2026-06-19 19:15:00"),
            finished_at: Time.zone.parse("2026-06-19 20:02:10")
          )
          post "/admin/session", params: { password: "secret-password" }

          get "/matches/#{match.id}"

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("Finish match")
          expect(response.body).to include("Add goal for #{match.home_team.name}")
          expect(response.body).to include("Add goal for #{match.away_team.name}")
          expect(response.body).to include("Add goal")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end
  end

  describe "PATCH /matches/:id/finish" do
    context "when the visitor is not signed in as admin" do
      it "does not finish the match" do
        match = create(:match, started_at: Time.zone.parse("2026-06-19 19:15:00"))

        patch "/matches/#{match.id}/finish"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
        expect(match.reload.finished_at).to be_nil
      end
    end

    context "when the visitor is signed in as admin" do
      it "finishes the match and marks the match day as finished when all matches are done" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match_day = create(:match_day, status: "in_progress")
          match = create(:match, match_day: match_day, started_at: Time.zone.parse("2026-06-19 19:15:00"))
          post "/admin/session", params: { password: "secret-password" }

          travel_to Time.zone.parse("2026-06-19 20:02:10") do
            patch "/matches/#{match.id}/finish"
          end

          expect(response).to redirect_to(match_path(match))
          expect(flash[:notice]).to eq("Mecz zakończony")
          expect(match.reload.finished_at).to eq(Time.zone.parse("2026-06-19 20:02:10"))
          expect(match_day.reload.status).to eq("finished")
          expect(match.home_team.reload.result).to eq(Team::RESULT_DRAW)
          expect(match.away_team.reload.result).to eq(Team::RESULT_DRAW)
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end

      it "keeps the match day in progress when another match is still open" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match_day = create(:match_day, status: "in_progress")
          match = create(:match, match_day: match_day, started_at: Time.zone.parse("2026-06-19 19:15:00"))
          create(:match, match_day: match_day, started_at: Time.zone.parse("2026-06-19 19:20:00"))
          post "/admin/session", params: { password: "secret-password" }

          patch "/matches/#{match.id}/finish"

          expect(response).to redirect_to(match_path(match))
          expect(flash[:notice]).to eq("Mecz zakończony")
          expect(match.reload.finished_at).to be_present
          expect(match_day.reload.status).to eq("in_progress")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end

      it "rejects finishing a match that is not in progress" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match = create(:match, started_at: nil, finished_at: nil)
          post "/admin/session", params: { password: "secret-password" }

          patch "/matches/#{match.id}/finish"

          expect(response).to redirect_to(match_path(match))
          expect(flash[:alert]).to eq("Nie udało się zakończyć meczu")
          expect(match.reload.finished_at).to be_nil
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end

      it "stores win and loss results for the playing teams" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match_day = create(:match_day, status: "in_progress")
          match = create(
            :match,
            match_day: match_day,
            home_score: 3,
            away_score: 1,
            started_at: Time.zone.parse("2026-06-19 19:15:00")
          )
          post "/admin/session", params: { password: "secret-password" }

          patch "/matches/#{match.id}/finish"

          expect(response).to redirect_to(match_path(match))
          expect(match.home_team.reload.result).to eq(Team::RESULT_WIN)
          expect(match.away_team.reload.result).to eq(Team::RESULT_LOSS)
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end
  end

  describe "PATCH /matches/:id/start" do
    it "requires admin access" do
      match = create(:match, started_at: nil)

      patch "/matches/#{match.id}/start"

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Admin access required")
    end

    it "starts a prepared match" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day, status: "ready")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: create(:player))
        create(:team_player, team: away_team, player: create(:player, nickname: "away", phone: "+48999999998"))
        match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
        home_team.update!(match:)
        away_team.update!(match:)
        post "/admin/session", params: { password: "secret-password" }

        travel_to Time.zone.parse("2026-06-19 19:15:00") do
          patch "/matches/#{match.id}/start"
        end

        expect(response).to redirect_to(match_path(match))
        expect(flash[:notice]).to eq("Mecz rozpoczęty")
        expect(match.reload.started_at).to eq(Time.zone.parse("2026-06-19 19:15:00"))
        expect(match_day.reload.status).to eq("in_progress")
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end

    it "redirects with an alert when the match cannot start" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match = create(:match, started_at: nil)
        post "/admin/session", params: { password: "secret-password" }

        patch "/matches/#{match.id}/start"

        expect(response).to redirect_to(match_path(match))
        expect(flash[:alert]).to eq("Nie udało się rozpocząć meczu")
        expect(match.reload.started_at).to be_nil
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end
  end

  describe "PATCH /matches/:id/update_lineup" do
    it "saves an edited pre-match lineup for admins" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day:)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997")
        create(:match_day_player, match_day:, player: first_player)
        create(:match_day_player, match_day:, player: second_player)
        create(:match_day_player, match_day:, player: third_player)
        home_team = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: first_player)
        create(:team_player, team: away_team, player: second_player)
        match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
        home_team.update!(match:)
        away_team.update!(match:)
        post "/admin/session", params: { password: "secret-password" }

        patch "/matches/#{match.id}/update_lineup", params: {
          match: {
            teams_data: [
              { id: home_team.id, name: "Team A", player_ids: [ second_player.id.to_s ], captain_id: second_player.id.to_s },
              { id: away_team.id, name: "Team B", player_ids: [ first_player.id.to_s ], captain_id: third_player.id.to_s },
              { name: "Waiting", player_ids: [ third_player.id.to_s ], captain_id: third_player.id.to_s }
            ]
          }
        }

        expect(response).to redirect_to(match_path(match))
        expect(flash[:notice]).to eq("Skład został zaktualizowany")
        expect(match.reload.home_team.players).to contain_exactly(second_player)
        expect(match.away_team.players).to contain_exactly(first_player)
        expect(match.teams.find_by!(name: "Waiting").players).to contain_exactly(third_player)
        expect(match.home_team.captain).to eq(second_player)
        expect(match.away_team.captain).to be_nil
        expect(match.teams.find_by!(name: "Waiting").captain).to eq(third_player)
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end

    it "redirects with an alert when the edited lineup is invalid" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day:)
        player = create(:player)
        create(:match_day_player, match_day:, player:)
        home_team = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player:)
        match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
        home_team.update!(match:)
        away_team.update!(match:)
        post "/admin/session", params: { password: "secret-password" }

        patch "/matches/#{match.id}/update_lineup", params: {
          match: {
            teams_data: [
              { id: home_team.id, name: "Team A", player_ids: [ player.id.to_s ] },
              { id: away_team.id, name: "Team B", player_ids: [ player.id.to_s ] }
            ]
          }
        }

        expect(response).to redirect_to(match_path(match))
        expect(flash[:alert]).to eq("Player cannot be assigned to more than one lineup team")
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end
  end

  describe "PATCH /matches/:id/reset_to_baseline" do
    it "restores the baseline lineup for admins" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day:)
        baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE)
        baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE)
        waiting_team = create(:team, team_setup:, name: "Waiting", team_type: Team::TEAM_TYPE_BASELINE, playing: false)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997")
        create(:team_player, team: baseline_team_a, player: first_player)
        create(:team_player, team: baseline_team_b, player: second_player)
        create(:team_player, team: waiting_team, player: third_player)
        home_team = create(:team, team_setup:, match: nil, name: "Old Team A", team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, match: nil, name: "Old Team B", team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: second_player)
        create(:team_player, team: away_team, player: first_player)
        match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
        home_team.update!(match:)
        away_team.update!(match:)
        post "/admin/session", params: { password: "secret-password" }

        patch "/matches/#{match.id}/reset_to_baseline"

        expect(response).to redirect_to(match_path(match))
        expect(flash[:notice]).to eq("Skład przywrócony do bazowego")
        expect(match.reload.home_team.players).to contain_exactly(first_player)
        expect(match.away_team.players).to contain_exactly(second_player)
        expect(match.teams.find_by!(name: "Waiting").players).to contain_exactly(third_player)
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end

    it "redirects with an alert when no baseline teams are available" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, match: nil, name: "Old Team A", team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, match: nil, name: "Old Team B", team_type: Team::TEAM_TYPE_MATCH)
        match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
        home_team.update!(match:)
        away_team.update!(match:)
        post "/admin/session", params: { password: "secret-password" }

        patch "/matches/#{match.id}/reset_to_baseline"

        expect(response).to redirect_to(match_path(match))
        expect(flash[:alert]).to eq("Nie udało się przywrócić składu")
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end
  end

  describe "PATCH /matches/:id/copy_previous_lineup" do
    it "restores the previous match lineup for admins" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day:)
        baseline_team_a = create(:team, team_setup:, name: "Team A", team_type: Team::TEAM_TYPE_BASELINE)
        baseline_team_b = create(:team, team_setup:, name: "Team B", team_type: Team::TEAM_TYPE_BASELINE)
        previous_match = create(:match, match_day:, home_team: baseline_team_a, away_team: baseline_team_b)
        first_player = create(:player)
        second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998")
        third_player = create(:player, name: "Third", nickname: "third", phone: "+48999999997")
        previous_home_team = create(:team, team_setup:, match: previous_match, name: "Team A", team_type: Team::TEAM_TYPE_MATCH, source_team: baseline_team_a)
        previous_away_team = create(:team, team_setup:, match: previous_match, name: "Team B", team_type: Team::TEAM_TYPE_MATCH, source_team: baseline_team_b)
        previous_waiting_team = create(:team, team_setup:, match: previous_match, name: "Waiting", team_type: Team::TEAM_TYPE_MATCH, playing: false)
        previous_match.update!(home_team: previous_home_team, away_team: previous_away_team)
        create(:team_player, team: previous_home_team, player: first_player)
        create(:team_player, team: previous_away_team, player: second_player)
        create(:team_player, team: previous_waiting_team, player: third_player)
        current_home_team = create(:team, team_setup:, match: nil, name: "Current A", team_type: Team::TEAM_TYPE_MATCH)
        current_away_team = create(:team, team_setup:, match: nil, name: "Current B", team_type: Team::TEAM_TYPE_MATCH)
        match = create(:match, match_day:, home_team: current_home_team, away_team: current_away_team, started_at: nil)
        current_home_team.update!(match:)
        current_away_team.update!(match:)
        post "/admin/session", params: { password: "secret-password" }

        patch "/matches/#{match.id}/copy_previous_lineup"

        expect(response).to redirect_to(match_path(match))
        expect(flash[:notice]).to eq("Skład z poprzedniego meczu został skopiowany")
        expect(match.reload.home_team.players).to contain_exactly(first_player)
        expect(match.away_team.players).to contain_exactly(second_player)
        expect(match.teams.find_by!(name: "Waiting").players).to contain_exactly(third_player)
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end

    it "redirects with an alert when no previous match is available" do
      begin
        original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
        ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
        match_day = create(:match_day)
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, match: nil, name: "Current A", team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, match: nil, name: "Current B", team_type: Team::TEAM_TYPE_MATCH)
        match = create(:match, match_day:, home_team:, away_team:, started_at: nil)
        home_team.update!(match:)
        away_team.update!(match:)
        post "/admin/session", params: { password: "secret-password" }

        patch "/matches/#{match.id}/copy_previous_lineup"

        expect(response).to redirect_to(match_path(match))
        expect(flash[:alert]).to eq("Nie udało się skopiować poprzedniego składu")
      ensure
        if original_admin_password.nil?
          ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
        else
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
        end
      end
    end
  end
end
