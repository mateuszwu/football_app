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
end
