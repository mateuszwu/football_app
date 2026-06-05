require "rails_helper"

RSpec.describe "Players" do
  describe "GET /players/:id" do
    context "when the player is approved and active" do
      it "renders the public profile with match history and without private phone data" do
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
        older_match_day = create(:match_day, played_on: Date.new(2026, 5, 22), status: "finished", season: create(:season, name: "Spring 2026"))
        latest_match_day = create(:match_day, played_on: Date.new(2026, 5, 29), status: "ready", season: create(:season, name: "Summer 2026"))
        create(:match_day_player, player: player, match_day: older_match_day)
        create(:match_day_player, player: player, match_day: latest_match_day)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("adam")
        expect(response.body).to include("DEF")
        expect(response.body).to include("Solid defender")
        expect(response.body).to include("Historia meczow")
        expect(response.body).to include("2026-05-29")
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("ready")
        expect(response.body).to include("2026-05-22")
        expect(response.body).to include("Spring 2026")
        expect(response.body.index("2026-05-29")).to be < response.body.index("2026-05-22")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the player has not played any match days" do
      it "renders an empty history state" do
        player = create(:player, approval_status: "approved", active: true)

        get "/players/#{player.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak rozegranych meczow.")
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
