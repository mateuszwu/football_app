require "rails_helper"

RSpec.describe "Seasons" do
  describe "GET /seasons/:id" do
    context "when the season has match days and players" do
      it "renders public season stats without private phone data" do
        season = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 8, 31))
        player = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111")
        other_player = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222")
        first_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5), status: "finished")
        latest_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 12), status: "ready")
        create(:match_day_player, match_day: first_match_day, player: player)
        create(:match_day_player, match_day: latest_match_day, player: player)
        create(:match_day_player, match_day: latest_match_day, player: other_player)

        get "/seasons/#{season.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("2026-06-01")
        expect(response.body).to include("2026-08-31")
        expect(response.body).to include("Match days")
        expect(response.body).to include("Zawodnicy")
        expect(response.body).to include("Wystepy")
        expect(response.body).to include("Leaderboard sezonu")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("adam")
        expect(response.body).to include("2 appearances")
        expect(response.body).to include("Marek Kowalski")
        expect(response.body).to include("marek")
        expect(response.body).to include("1 appearance")
        expect(response.body.index("Adam Nowak")).to be < response.body.index("Marek Kowalski")
        expect(response.body).to include("2026-06-12")
        expect(response.body).to include("ready")
        expect(response.body).to include("2026-06-05")
        expect(response.body).to include("finished")
        expect(response.body.index("2026-06-12")).to be < response.body.index("2026-06-05")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the season has no match days" do
      it "renders an empty state" do
        season = create(:season, name: "Summer 2026")

        get "/seasons/#{season.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("Brak zawodnikow w leaderboardzie sezonu.")
        expect(response.body).to include("Brak match days w tym sezonie.")
      end
    end
  end
end
