require "rails_helper"

RSpec.describe "Admin players" do
  describe "GET /admin/players" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        create(:player, phone: "+48111111111")

        get "/admin/players"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders players with private phone data" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          create(
            :player,
            name: "Adam Nowak",
            nickname: "adam",
            phone: "+48111111111",
            role_code: "DEF",
            approval_status: "approved",
            active: true
          )
          create(
            :player,
            name: "Bartek Kowal",
            nickname: "bartek",
            phone: "+48222222222",
            role_code: "ATT",
            approval_status: "pending",
            active: false
          )

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/players"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Adam Nowak")
          expect(response.body).to include("Bartek Kowal")
          expect(response.body).to include("+48111111111")
          expect(response.body).to include("+48222222222")
          expect(response.body).to include("approved")
          expect(response.body).to include("pending")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when no players exist" do
      it "renders an empty state for admins" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/players"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Brak zawodnikow do wyswietlenia.")
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

  describe "GET /admin/players/:id/edit" do
    context "when the visitor is not signed in as admin" do
      it "redirects to the public home page" do
        player = create(:player)

        get "/admin/players/#{player.id}/edit"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Admin access required")
      end
    end

    context "when the visitor is signed in as admin" do
      it "renders the edit form with private phone data" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111")

          post "/admin/session", params: { password: "secret-password" }
          get "/admin/players/#{player.id}/edit"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Edytuj zawodnika")
          expect(response.body).to include("Adam Nowak")
          expect(response.body).to include("+48111111111")
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

  describe "PATCH /admin/players/:id" do
    context "when the visitor is not signed in as admin" do
      it "does not update the player" do
        player = create(:player, name: "Adam Nowak")

        patch "/admin/players/#{player.id}", params: { player: { name: "Changed" } }

        expect(response).to redirect_to(root_path)
        expect(player.reload.name).to eq("Adam Nowak")
      end
    end

    context "when the visitor is signed in as admin and params are valid" do
      it "updates the player" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          player = create(:player, active: true)

          post "/admin/session", params: { password: "secret-password" }
          patch(
            "/admin/players/#{player.id}",
            params: {
              player: {
                name: "Updated Player",
                nickname: "updated",
                phone: "+48999999999",
                description: "Updated description",
                role_code: "MID",
                approval_status: "approved",
                active: "0"
              }
            }
          )

          expect(response).to redirect_to(admin_players_path)
          player.reload
          expect(player.name).to eq("Updated Player")
          expect(player.nickname).to eq("updated")
          expect(player.phone).to eq("+48999999999")
          expect(player.description).to eq("Updated description")
          expect(player.role_code).to eq("MID")
          expect(player.approval_status).to eq("approved")
          expect(player).not_to be_active
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
          player = create(:player, name: "Adam Nowak")

          post "/admin/session", params: { password: "secret-password" }
          patch "/admin/players/#{player.id}", params: { player: { name: "" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Name can&#39;t be blank")
          expect(player.reload.name).to eq("Adam Nowak")
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

  describe "PATCH /admin/players/:id/approve" do
    context "when the visitor is not signed in as admin" do
      it "does not approve the player" do
        player = create(:player, approval_status: "pending")

        patch "/admin/players/#{player.id}/approve"

        expect(response).to redirect_to(root_path)
        expect(player.reload.approval_status).to eq("pending")
      end
    end

    context "when the visitor is signed in as admin" do
      it "approves the player" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          player = create(:player, approval_status: "pending", active: false, approved_at: nil, rejected_at: Time.current)

          post "/admin/session", params: { password: "secret-password" }
          patch "/admin/players/#{player.id}/approve"

          expect(response).to redirect_to(admin_players_path)
          player.reload
          expect(player.approval_status).to eq("approved")
          expect(player).to be_active
          expect(player.approved_at).to be_present
          expect(player.rejected_at).to be_nil
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

  describe "PATCH /admin/players/:id/reject" do
    context "when the visitor is not signed in as admin" do
      it "does not reject the player" do
        player = create(:player, approval_status: "pending")

        patch "/admin/players/#{player.id}/reject"

        expect(response).to redirect_to(root_path)
        expect(player.reload.approval_status).to eq("pending")
      end
    end

    context "when the visitor is signed in as admin" do
      it "rejects the player" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"
          player = create(:player, approval_status: "pending", active: true, approved_at: Time.current, rejected_at: nil)

          post "/admin/session", params: { password: "secret-password" }
          patch "/admin/players/#{player.id}/reject"

          expect(response).to redirect_to(admin_players_path)
          player.reload
          expect(player.approval_status).to eq("rejected")
          expect(player).not_to be_active
          expect(player.rejected_at).to be_present
          expect(player.approved_at).to be_nil
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
