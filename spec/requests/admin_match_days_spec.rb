require "rails_helper"

RSpec.describe "Admin match days" do
  describe "GET /admin/match_days" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        get "/admin/match_days"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders match days with season and status" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          season = create(:season, name: "Spring 2026")
          create(:match_day, season: season, played_on: Date.new(2026, 6, 5), status: "setup")

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/match_days"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Spring 2026")
          expect(response.body).to include("2026-06-05")
          expect(response.body).to include("setup")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when no match days exist" do
      it "renders an empty state for admins" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/match_days"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Brak match days do wyswietlenia.")
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

  describe "GET /admin/match_days/new" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        get "/admin/match_days/new"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders the setup form with the current season selected" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          create(:season, name: "Old Season", active: true, starts_on: Date.new(2026, 1, 1))
          create(:season, name: "Current Season", active: true, starts_on: Date.new(2026, 6, 1))
          create(:player, name: "Adam", nickname: "adam", approval_status: "approved", active: true)
          create(:player, name: "Bartek", nickname: "bartek", approval_status: "pending", active: true)

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/match_days/new"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Nowy match day")
          expect(response.body).to include("Current Season")
          expect(response.body).to include("setup")
          expect(response.body).to include("Adam (adam)")
          expect(response.body).not_to include("Bartek (bartek)")
          expect(response.body).to include("Manualny builder bazowych zespolow")
          expect(response.body).to include("Team A")
          expect(response.body).to include("Team B")
          expect(response.body).to include("selected=\"selected\"")
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

  describe "POST /admin/match_days" do
    context "when the visitor is not signed in as admin" do
      it "does not create the match day" do
        season = create(:season)

        post "/admin/match_days", params: { match_day: { season_id: season.id, played_on: "2026-06-05" } }

        expect(response).to redirect_to(root_path)
        expect(MatchDay.count).to eq(0)
      end
    end

    context "when the visitor is signed in as admin and params are valid" do
      it "creates the match day" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          season = create(:season)
          first_player = create(:player, approval_status: "approved", active: true)
          second_player = create(:player, name: "Second", nickname: "second", phone: "+48999999998", approval_status: "approved", active: true)

          post "/admin/session", params: { password: "secret-password" }
          post "/admin/match_days", params: {
            match_day: {
              season_id: season.id,
              played_on: "2026-06-05",
              player_ids: [ first_player.id.to_s, second_player.id.to_s ],
              team_a_player_ids: [ first_player.id.to_s ],
              team_b_player_ids: [ second_player.id.to_s ]
            }
          }

          expect(response).to redirect_to(admin_match_days_path)
          match_day = MatchDay.find_by!(season: season, played_on: Date.new(2026, 6, 5))
          expect(match_day.status).to eq("ready")
          expect(match_day.players).to contain_exactly(first_player, second_player)
          expect(match_day.teams.find_by!(name: "Team A").players).to contain_exactly(first_player)
          expect(match_day.teams.find_by!(name: "Team B").players).to contain_exactly(second_player)
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when the visitor is signed in as admin and params are invalid" do
      it "renders validation errors" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          create(:season)

          post "/admin/session", params: { password: "secret-password" }
          post "/admin/match_days", params: { match_day: { season_id: "", played_on: "" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Season must exist")
          expect(response.body).to include("Played on can&#39;t be blank")
          expect(MatchDay.count).to eq(0)
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

  describe "GET /admin/match_days/:id/edit" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        match_day = create(:match_day)

        get "/admin/match_days/#{match_day.id}/edit"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders the edit form" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          season = create(:season, name: "Spring 2026")
          player = create(:player, name: "Adam", nickname: "adam", approval_status: "approved", active: true)
          match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5))
          create(:match_day_player, match_day: match_day, player: player)

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/match_days/#{match_day.id}/edit"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Edytuj match day")
          expect(response.body).to include("Spring 2026")
          expect(response.body).to include("2026-06-05")
          expect(response.body).to include("Adam (adam)")
          expect(response.body).to include("Manualny builder bazowych zespolow")
          expect(response.body).to include("checked=\"checked\"")
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

  describe "PATCH /admin/match_days/:id" do
    context "when the visitor is not signed in as admin" do
      it "does not update the match day" do
        match_day = create(:match_day, played_on: Date.new(2026, 6, 5))

        patch "/admin/match_days/#{match_day.id}", params: { match_day: { played_on: "2026-06-12" } }

        expect(response).to redirect_to(root_path)
        expect(match_day.reload.played_on).to eq(Date.new(2026, 6, 5))
      end
    end

    context "when the visitor is signed in as admin and params are valid" do
      it "updates the match day" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          season = create(:season)
          other_season = create(:season, name: "Season 2 Match Day", starts_on: Date.new(2026, 7, 1))
          original_player = create(:player, approval_status: "approved", active: true)
          new_player = create(:player, name: "New Player", nickname: "new", phone: "+48987654321", approval_status: "approved", active: true)
          match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5))
          create(:match_day_player, match_day: match_day, player: original_player)
          team_setup = create(:team_setup, match_day: match_day)
          original_team = create(:team, team_setup: team_setup, name: "Team A", team_type: "baseline")
          create(:team_player, team: original_team, player: original_player)

          post "/admin/session", params: { password: "secret-password" }
          patch "/admin/match_days/#{match_day.id}", params: {
            match_day: {
              season_id: other_season.id,
              played_on: "2026-06-12",
              player_ids: [ original_player.id.to_s, new_player.id.to_s ],
              team_a_player_ids: [],
              team_b_player_ids: [ new_player.id.to_s ]
            }
          }

          expect(response).to redirect_to(admin_match_days_path)
          match_day.reload
          expect(match_day.season).to eq(other_season)
          expect(match_day.played_on).to eq(Date.new(2026, 6, 12))
          expect(match_day.status).to eq("setup")
          expect(match_day.players).to contain_exactly(original_player, new_player)
          expect(match_day.teams.find_by!(name: "Team B").players).to contain_exactly(new_player)
          expect(match_day.teams.find_by(name: "Team A")).to be_nil
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when the visitor is signed in as admin and params are invalid" do
      it "renders validation errors" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          match_day = create(:match_day, played_on: Date.new(2026, 6, 5))

          post "/admin/session", params: { password: "secret-password" }
          patch "/admin/match_days/#{match_day.id}", params: { match_day: { season_id: "", played_on: "" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Season must exist")
          expect(response.body).to include("Played on can&#39;t be blank")
          expect(match_day.reload.played_on).to eq(Date.new(2026, 6, 5))
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
end
