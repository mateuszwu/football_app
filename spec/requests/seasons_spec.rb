require "rails_helper"

RSpec.describe "Seasons" do
  describe "GET /seasons/:id" do
    context "when the season has match days and players" do
      it "renders public season leaderboards without private phone data" do
        spring = create(:season, name: "Spring 2026", starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 5, 31))
        season = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 8, 31))
        scorer = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        assister = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222", approval_status: "approved", active: true)
        def_player = create(:player, name: "Piotr Lis", nickname: "piotr", phone: "+48333333333", approval_status: "approved", active: true)
        latest_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 12), status: "ready")
        first_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5), status: "finished")
        create(:match_day_player, match_day: first_match_day, player: scorer)
        create(:match_day_player, match_day: latest_match_day, player: scorer)
        create(:match_day_player, match_day: latest_match_day, player: assister)
        create(:match_day_player, match_day: latest_match_day, player: def_player)
        create(:player_season_stat, season: season, player: scorer, elo: 1042, goals: 5, assists: 1, mvp_votes_count: 3, def_votes_count: 0)
        create(:player_season_stat, season: season, player: assister, elo: 1030, goals: 2, assists: 6, mvp_votes_count: 1, def_votes_count: 1)
        create(:player_season_stat, season: season, player: def_player, elo: 1018, goals: 0, assists: 2, mvp_votes_count: 0, def_votes_count: 4)
        create(:player_season_stat, season: spring, player: scorer, elo: 990, goals: 1, assists: 1, mvp_votes_count: 0, def_votes_count: 0)

        get "/seasons/#{season.id}", params: { season_id: season.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("2026-06-01")
        expect(response.body).to include("2026-08-31")
        expect(response.body).to include("Sezon")
        expect(response.body).to include("Filtruj")
        expect(response.body).to include("Match days")
        expect(response.body).to include("Zawodnicy")
        expect(response.body).to include("Wystepy")
        expect(response.body).to include("Ranking Elo")
        expect(response.body).to include("Top strzelcy")
        expect(response.body).to include("Top asysty")
        expect(response.body).to include("Top MVP")
        expect(response.body).to include("Top DEF")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("adam")
        expect(response.body).to include("Marek Kowalski")
        expect(response.body).to include("marek")
        expect(response.body).to include("Piotr Lis")
        expect(response.body).to include("1042 Elo")
        expect(response.body).to include("5 goli")
        expect(response.body).to include("6 asyst")
        expect(response.body).to include("3 MVP")
        expect(response.body).to include("4 DEF")
        expect(response.body.index("Adam Nowak")).to be < response.body.index("Marek Kowalski")
        expect(response.body).to include("2026-06-12")
        expect(response.body).to include("ready")
        expect(response.body).to include("2026-06-05")
        expect(response.body).to include("finished")
        expect(response.body.index("2026-06-12")).to be < response.body.index("2026-06-05")
        expect(response.body).to include("Spring 2026")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("+48333333333")
        expect(response.body).not_to include("phone")
      end
    end

    context "when the season has no match days" do
      it "renders an empty state" do
        season = create(:season, name: "Summer 2026")

        get "/seasons/#{season.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("Brak zawodnikow w rankingu Elo.")
        expect(response.body).to include("Brak strzelcow w tym sezonie.")
        expect(response.body).to include("Brak asyst w tym sezonie.")
        expect(response.body).to include("Brak glosow MVP w tym sezonie.")
        expect(response.body).to include("Brak glosow DEF w tym sezonie.")
        expect(response.body).to include("Brak match days w tym sezonie.")
      end
    end
  end
end
