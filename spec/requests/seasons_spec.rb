require "rails_helper"

RSpec.describe "Seasons" do
  describe "GET /seasons/:id" do
    context "when the season has match days and players" do
      it "renders public season stats without private phone data" do
        season = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 8, 31))
        player = create(:player, name: "Adam Nowak", phone: "+48111111111")
        first_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5), status: "finished")
        latest_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 12), status: "ready")
        create(:match_day_player, match_day: first_match_day, player: player)
        create(:match_day_player, match_day: latest_match_day, player: player)

        get "/seasons/#{season.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("2026-06-01")
        expect(response.body).to include("2026-08-31")
        expect(response.body).to include("Match days")
        expect(response.body).to include("Zawodnicy")
        expect(response.body).to include("Wystepy")
        expect(response.body).to include("2026-06-12")
        expect(response.body).to include("ready")
        expect(response.body).to include("2026-06-05")
        expect(response.body).to include("finished")
        expect(response.body.index("2026-06-12")).to be < response.body.index("2026-06-05")
        expect(response.body).not_to include("Adam Nowak")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the season has no match days" do
      it "renders an empty state" do
        season = create(:season, name: "Summer 2026")

        get "/seasons/#{season.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("Brak match days w tym sezonie.")
      end
    end
  end
end
