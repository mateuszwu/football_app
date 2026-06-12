require "rails_helper"

RSpec.describe "Admin seasons" do
  describe "GET /admin/seasons" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        create(:season, name: "Spring 2026")

        get "/admin/seasons"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders seasons with settings" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          create(
            :season,
            name: "Spring 2026",
            starts_on: Date.new(2026, 3, 1),
            ends_on: Date.new(2026, 6, 30),
            active: true,
            status: Season::STATUS_ACTIVE,
            initial_elo: 1100,
            elo_k_factor: 24,
            elo_k_value: 16,
            player_advantage_elo: 40,
            mvp_vote_bonus: 8,
            def_vote_bonus: 6,
            goal_points: 1.0,
            assist_points: 0.8
          )

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/seasons"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Spring 2026")
          expect(response.body).to include("2026-03-01")
          expect(response.body).to include("2026-06-30")
          expect(response.body).to include("1100")
          expect(response.body).to include("24")
          expect(response.body).to include("16.0")
          expect(response.body).to include("40.0")
          expect(response.body).to include("8")
          expect(response.body).to include("6")
          expect(response.body).to include("1.0")
          expect(response.body).to include("0.8")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when no seasons exist" do
      it "renders an empty state for admins" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/seasons"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Brak sezonow do wyswietlenia.")
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

  describe "GET /admin/seasons/new" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        get "/admin/seasons/new"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders the new season form" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/seasons/new"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Nowy sezon")
          expect(response.body).to include("Initial Elo")
          expect(response.body).to include("Elo K value")
          expect(response.body).to include("Player advantage Elo")
          expect(response.body).to include("MVP bonus")
          expect(response.body).to include("DEF bonus")
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

  describe "POST /admin/seasons" do
    context "when the visitor is not signed in as admin" do
      it "does not create the season" do
        post "/admin/seasons", params: { season: { name: "Spring 2026", starts_on: "2026-03-01" } }

        expect(response).to redirect_to(root_path)
        expect(Season.find_by(name: "Spring 2026")).to be_nil
      end
    end

    context "when the visitor is signed in as admin and params are valid" do
      it "creates the season" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          post "/admin/session", params: { password: "secret-password" }
          post(
            "/admin/seasons",
            params: {
              season: {
                name: "Spring 2026",
                starts_on: "2026-03-01",
                ends_on: "2026-06-30",
                status: Season::STATUS_ACTIVE,
                initial_elo: "1100",
                elo_k_factor: "24",
                elo_k_value: "16",
                player_advantage_elo: "40",
                season_elo_carryover_factor: "0.5",
                goal_points: "1.0",
                assist_points: "0.8",
                mvp_max_points: "4.0",
                def_max_points: "3.0",
                voting_bonus_cap: "5.0",
                expected_voters_count: "5",
                elo_settings_locked: "0",
                mvp_vote_bonus: "8",
                def_vote_bonus: "6"
              }
            }
          )

          expect(response).to redirect_to(admin_seasons_path)
          season = Season.find_by!(name: "Spring 2026")
          expect(season.starts_on).to eq(Date.new(2026, 3, 1))
          expect(season.ends_on).to eq(Date.new(2026, 6, 30))
          expect(season).to be_active
          expect(season.status).to eq(Season::STATUS_ACTIVE)
          expect(season.initial_elo).to eq(1100)
          expect(season.elo_k_factor).to eq(24)
          expect(season.elo_k_value).to eq(16)
          expect(season.player_advantage_elo).to eq(40)
          expect(season.season_elo_carryover_factor).to eq(0.5)
          expect(season.goal_points).to eq(1.0)
          expect(season.assist_points).to eq(0.8)
          expect(season.mvp_max_points).to eq(4.0)
          expect(season.def_max_points).to eq(3.0)
          expect(season.voting_bonus_cap).to eq(5.0)
          expect(season.expected_voters_count).to eq(5)
          expect(season.mvp_vote_bonus).to eq(8)
          expect(season.def_vote_bonus).to eq(6)
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

          post "/admin/session", params: { password: "secret-password" }
          post "/admin/seasons", params: { season: { name: "", starts_on: "" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Name can&#39;t be blank")
          expect(response.body).to include("Starts on can&#39;t be blank")
          expect(Season.count).to eq(0)
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

  describe "GET /admin/seasons/:id/edit" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        season = create(:season)

        get "/admin/seasons/#{season.id}/edit"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders the edit form" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          season = create(:season, name: "Spring 2026", initial_elo: 1100, status: Season::STATUS_ACTIVE)

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/seasons/#{season.id}/edit"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Edytuj sezon")
          expect(response.body).to include("Spring 2026")
          expect(response.body).to include("1100")
          expect(response.body).to include("active")
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

  describe "PATCH /admin/seasons/:id" do
    context "when the visitor is not signed in as admin" do
      it "does not update the season" do
        season = create(:season, name: "Spring 2026")

        patch "/admin/seasons/#{season.id}", params: { season: { name: "Changed" } }

        expect(response).to redirect_to(root_path)
        expect(season.reload.name).to eq("Spring 2026")
      end
    end

    context "when the visitor is signed in as admin and params are valid" do
      it "updates the season" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          season = create(:season, active: true, status: Season::STATUS_ACTIVE)

          post "/admin/session", params: { password: "secret-password" }
          patch(
            "/admin/seasons/#{season.id}",
            params: {
              season: {
                name: "Updated Season",
                starts_on: "2026-04-01",
                ends_on: "",
                status: Season::STATUS_CLOSED,
                initial_elo: "1200",
                elo_k_factor: "20",
                elo_k_value: "18",
                player_advantage_elo: "50",
                season_elo_carryover_factor: "0.6",
                goal_points: "1.5",
                assist_points: "0.9",
                mvp_max_points: "4.5",
                def_max_points: "3.5",
                voting_bonus_cap: "5.5",
                expected_voters_count: "6",
                elo_settings_locked: "1",
                mvp_vote_bonus: "9",
                def_vote_bonus: "7"
              }
            }
          )

          expect(response).to redirect_to(admin_seasons_path)
          season.reload
          expect(season.name).to eq("Updated Season")
          expect(season.starts_on).to eq(Date.new(2026, 4, 1))
          expect(season.ends_on).to be_nil
          expect(season).not_to be_active
          expect(season.status).to eq(Season::STATUS_CLOSED)
          expect(season.initial_elo).to eq(1200)
          expect(season.elo_k_factor).to eq(20)
          expect(season.elo_k_value).to eq(18)
          expect(season.player_advantage_elo).to eq(50)
          expect(season.season_elo_carryover_factor).to eq(0.6)
          expect(season.goal_points).to eq(1.5)
          expect(season.assist_points).to eq(0.9)
          expect(season.mvp_max_points).to eq(4.5)
          expect(season.def_max_points).to eq(3.5)
          expect(season.voting_bonus_cap).to eq(5.5)
          expect(season.expected_voters_count).to eq(6)
          expect(season).to be_elo_settings_locked
          expect(season.mvp_vote_bonus).to eq(9)
          expect(season.def_vote_bonus).to eq(7)
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
          season = create(:season, name: "Spring 2026")

          post "/admin/session", params: { password: "secret-password" }
          patch "/admin/seasons/#{season.id}", params: { season: { name: "" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Name can&#39;t be blank")
          expect(season.reload.name).to eq("Spring 2026")
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

  describe "DELETE /admin/seasons/:id" do
    context "when the visitor is not signed in as admin" do
      it "does not delete the season" do
        season = create(:season)

        delete "/admin/seasons/#{season.id}"

        expect(response).to redirect_to(root_path)
        expect(Season.exists?(season.id)).to be(true)
      end
    end

    context "when the visitor is signed in as admin" do
      it "deletes the season" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          season = create(:season)

          post "/admin/session", params: { password: "secret-password" }
          delete "/admin/seasons/#{season.id}"

          expect(response).to redirect_to(admin_seasons_path)
          expect(Season.exists?(season.id)).to be(false)
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
