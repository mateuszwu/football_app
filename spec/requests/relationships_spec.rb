require "rails_helper"

RSpec.describe "Relationships" do
  describe "GET /relationships" do
    context "when public relationship data exists" do
      it "renders the public relationship graph page with a visual network and without private phone data" do
        adam = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222", approval_status: "approved", active: true)
        pending_player = create(:player, name: "Pending Player", nickname: "pending", phone: "+48333333333", approval_status: "pending", active: true)
        first_match_day = create(:match_day, played_on: Date.new(2026, 6, 5))
        second_match_day = create(:match_day, played_on: Date.new(2026, 6, 12))
        create(:match_day_player, player: adam, match_day: first_match_day)
        create(:match_day_player, player: marek, match_day: first_match_day)
        create(:match_day_player, player: adam, match_day: second_match_day)
        create(:match_day_player, player: marek, match_day: second_match_day)
        create(:match_day_player, player: pending_player, match_day: second_match_day)

        get "/relationships"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Graf relacji")
        expect(response.body).to include("Wizualna siec polaczen")
        expect(response.body).to include("Najmocniejsze polaczenia")
        expect(response.body).to include("Najlepsi teammatezi")
        expect(response.body).to include("<svg")
        expect(response.body).to include("relationship-graph__node")
        expect(response.body).to include("relationship-graph__edge")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("Marek Kowalski")
        expect(response.body).to include("2 shared match days")
        expect(response.body).to include(player_path(adam))
        expect(response.body).to include(player_path(marek))
        expect(response.body).not_to include("Pending Player")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("+48333333333")
        expect(response.body).not_to include("phone")
      end
    end

    context "when no public relationship data exists" do
      it "renders empty states" do
        get "/relationships"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak publicznych zawodnikow do narysowania grafu relacji.")
        expect(response.body).to include("Brak publicznych polaczen do wyswietlenia.")
        expect(response.body).to include("Brak publicznych zawodnikow do zbudowania grafu relacji.")
      end
    end
  end
end
