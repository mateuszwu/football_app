require "rails_helper"

RSpec.describe "Home page" do
  describe "GET /" do
    context "when public visitor opens the app" do
      it "renders the public dashboard and navigation" do
        path = root_path

        get path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Football App")
        expect(response.body).to include("Dashboard")
        expect(response.body).to include("Leaderboardy")
        expect(response.body).to include("Relacje")
        expect(response.body).to include("Zawodnicy")
        expect(response.body).to include("Dolacz")
        expect(response.body).to include("Zaloguj")
      end
    end

    context "when public visitor opens the app without player data" do
      it "does not render private phone data" do
        path = root_path

        get path

        expect(response.body).not_to include("phone")
        expect(response.body).not_to include("telefon")
      end
    end

    context "when public approved players exist" do
      it "renders links to public profiles without private phone data" do
        approved_player = create(
          :player,
          name: "Adam Nowak",
          nickname: "adam",
          phone: "+48111111111",
          approval_status: "approved",
          active: true
        )
        create(
          :player,
          name: "Pending Player",
          nickname: "pending",
          phone: "+48222222222",
          approval_status: "pending",
          active: true
        )

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include(player_path(approved_player))
        expect(response.body).not_to include("Pending Player")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
      end
    end

    context "when an active season exists" do
      it "renders a link to the season stats page" do
        season = create(:season, name: "Summer 2026", active: true)

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include(season_path(season))
      end
    end
  end
end
