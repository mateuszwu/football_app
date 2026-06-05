require "rails_helper"

RSpec.describe "Players" do
  describe "GET /players/:id" do
    context "when the player is approved and active" do
      it "renders the public profile without private phone data" do
        player = create(
          :player,
          name: "Adam Nowak",
          nickname: "adam",
          phone: "+48111111111",
          description: "Solid defender",
          role_code: "DEF",
          approval_status: "approved",
          active: true
        )

        get "/players/#{player.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("adam")
        expect(response.body).to include("DEF")
        expect(response.body).to include("Solid defender")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the player is pending approval" do
      it "does not render the public profile" do
        player = create(:player, approval_status: "pending", active: true)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the player is inactive" do
      it "does not render the public profile" do
        player = create(:player, approval_status: "approved", active: false)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
