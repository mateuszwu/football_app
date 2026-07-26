require "rails_helper"

RSpec.describe "Relationships" do
  describe "GET /relationships" do
    context "when public relationship data exists" do
      it "renders the public relationship graph page with a visual network and without private phone data" do
        adam = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222", approval_status: "approved", active: true)
        pending_player = create(:player, name: "Pending Player", nickname: "pending", phone: "+48333333333", approval_status: "pending", active: true)
        season = create(:season)

        5.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 6, index + 1), status: "finished")
          create(:match_day_player, player: adam, match_day:)
          create(:match_day_player, player: marek, match_day:)
          create(:match_day_player, player: pending_player, match_day:) if index == 1
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: home_team, player: adam)
          marek_team_player = create(:team_player, team: home_team, player: marek)
          match = create(
            :match,
            match_day:,
            home_team:,
            away_team:,
            home_score: 2,
            away_score: 1,
            finished_at: index.days.ago
          )
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: marek_team_player)
        end

        get "/relationships"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<h1>Synergia zawodników</h1>")
        expect(response.body).not_to include("SYNERGIA ZAWODNIKÓW")
        expect(response.body).not_to include("Mapa synergii")
        expect(response.body).to include("Najlepszy duet ogólnie")
        expect(response.body).to include("Najczęściej razem")
        expect(response.body).to include("Najskuteczniejszy duet")
        expect(response.body).to include("Najlepszy duet ofensywny")
        expect(response.body).to include("Jak liczony jest Najlepszy duet ogólnie")
        expect(response.body).to include("Jak liczony jest Najczęściej razem")
        expect(response.body).to include("Jak liczony jest Najskuteczniejszy duet")
        expect(response.body).to include("Jak liczony jest Najlepszy duet ofensywny")
        expect(response.body).to include("Wynik = wygrane × 3 + remisy + gole + asysty")
        expect(response.body).to include("Najpierw liczba wspólnych meczów")
        expect(response.body).to include("Win% = wygrane / wspólne mecze × 100")
        expect(response.body).to include("Najpierw asysty między sobą")
        expect(response.body).to include("synergy-summary-card__watermark")
        expect(response.body).to include("synergy-summary-card__label")
        expect(response.body).to include("synergy-summary-card__tooltip-control")
        summary_card = Nokogiri::HTML(response.body).at_css(".synergy-summary-card")
        label_row = summary_card.at_css(".synergy-summary-card__label-row")
        expect(label_row.css("button.synergy-summary-card__tooltip-control").size).to eq(1)
        expect(label_row.css(".synergy-summary-card__label").size).to eq(1)
        expect(label_row.element_children.first["class"]).to include("synergy-summary-card__tooltip-anchor")
        expect(summary_card.at_css(".synergy-summary-card__watermark")).not_to be_nil
        expect(response.body).to include("relationship-summary-player-group")
        expect(response.body).to include("relationship-summary-player-plus")
        expect(response.body).to include("synergy-summary-card__metric")
        expect(response.body).to include("synergy-summary-card__chip")
        expect(response.body).not_to include("relationship-avatar")
        expect(response.body).to include("Duety")
        expect(response.body).to include("Trio")
        expect(response.body).to include("Czwórki")
        expect(response.body).to include("Piątki")
        expect(response.body).to include("Graf relacji")
        expect(response.body).to include("2 zawodników")
        expect(response.body).to include("1 połączenie")
        expect(response.body).to include("100% wygranych")
        expect(response.body).to include("5 wspólnych meczów")
        expect(response.body).to include("5 asyst między sobą")
        expect(response.body).to include("10 G+A razem")
        expect(response.body).to include("5 goli · 5 asyst")
        table_headers = Nokogiri::HTML(response.body).css(".relationship-ranking-table thead th").map { |header| header.text.strip }
        expect(table_headers).to eq([ "#", "Duet", "Mecze", "Bilans", "Win%", "Ofensywa" ])
        document = Nokogiri::HTML(response.body)
        matches_header = document.at_css("th.relationship-ranking-table__matches")
        expect(matches_header["aria-sort"]).to eq("none")
        expect(matches_header.at_css("a")["href"]).to include("sort=matches")
        expect(matches_header.at_css("a")["href"]).to include("sort_direction=desc")
        mobile_headers = document.css(".relationship-mobile-ranking__header span").map { |header| header.text.squish }
        expect(mobile_headers).to eq([ "#", "Duet", "Mecze", "G+A", "Wzajemne asysty" ])
        mobile_row = document.at_css(".relationship-mobile-ranking__row")
        expect(mobile_row.at_css(".relationship-mobile-ranking__matches").text.squish).to eq("5 100%")
        expect(mobile_row.at_css(".relationship-mobile-ranking__offense").text.squish).to eq("10 (5g + 5a)")
        expect(mobile_row.at_css(".relationship-mobile-ranking__mutual").text.squish).to eq("5")
        expect(mobile_row.css(".relationship-mobile-player__avatar").size).to eq(2)
        expect(mobile_row.css(".relationship-mobile-player__name").map { |name| name.text.squish }).to contain_exactly("Adam Nowak", "Marek Kowalski")
        expect(response.body).to include("relationship-group-cell")
        expect(response.body).to include("player-identity-pill")
        expect(response.body).to include("player-identity-pill__icon")
        expect(response.body).to include("player-identity-pill__name")
        expect(response.body).to include(
          "player-identity-pill player-identity-pill--xs player-identity-pill--compact"
        )
        expect(response.body).to include(
          "player-identity-pill player-identity-pill--sm player-identity-pill--default"
        )
        expect(response.body).to include("relationship-win-rate--positive")
        expect(response.body).to include("5-0-0")
        expect(response.body).to include("10 G+A")
        expect(response.body).to include("5G • 5A")
        expect(response.body).to include("leaderboards-rank--gold")
        expect(response.body).to include("leaderboards-rank__medal")
        expect(response.body).to include("Ranking duetów")
        expect(response.body).to include("Jak czytać synergię?")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("Marek Kowalski")
        expect(response.body).to include(player_path(adam))
        expect(response.body).to include(player_path(marek))
        expect(response.body).not_to include("Publiczni zawodnicy")
        expect(response.body).not_to include("Widoczne połączenia")
        expect(response.body).not_to include("Najmocniejsze połączenia")
        expect(response.body).not_to include("Pełny graf relacji")
        expect(response.body).not_to include("relationship-graph__node")
        expect(response.body).not_to include("relationship-graph__edge")
        expect(response.body).not_to include("Najlepsi partnerzy")
        expect(response.body).not_to include("Pending Player")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("+48333333333")
        expect(response.body).not_to include("phone")
      end

      it "renders selected scalable ranking controls from query params" do
        adam = create(:player, name: "Adam Nowak", nickname: "adam", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Kowalski", nickname: "marek", approval_status: "approved", active: true)
        season = create(:season)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 1), status: "finished")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: adam)
        create(:team_player, team: home_team, player: marek)
        create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: Time.current)

        get "/relationships", params: {
          tab: "trios",
          direction: "worst",
          limit: 50,
          minimum_shared_matches: 1,
          player_filter: "Adam"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("value=\"trios\"")
        expect(response.body).to include("selected=\"selected\" value=\"worst\"")
        expect(response.body).to include("selected=\"selected\" value=\"50\"")
        expect(response.body).to include("value=\"1\" min=\"1\"")
        expect(response.body).to include("value=\"Adam\"")
        expect(response.body).to include("Trio")
      end

      it "renders shared competition ranks for exact ranking ties" do
        adam = create(:player, name: "Adam Nowak", nickname: "adam", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Kowal", nickname: "bartek", approval_status: "approved", active: true)
        cezary = create(:player, name: "Cezary Lis", nickname: "cezary", approval_status: "approved", active: true)
        opponent = create(:player, name: "Opponent Player", nickname: "opponent", approval_status: "approved", active: true)
        season = create(:season)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 6, index + 10), status: "finished")
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: home_team, player: adam)
          bartek_team_player = create(:team_player, team: home_team, player: bartek)
          cezary_team_player = create(:team_player, team: home_team, player: cezary)
          create(:team_player, team: away_team, player: opponent)
          match = create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 1, finished_at: index.days.ago)
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: bartek_team_player)
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: cezary_team_player, assistant_team_player: adam_team_player)
        end

        get "/relationships", params: { season_id: season.id }

        ranks = Nokogiri::HTML(response.body).css(".relationship-ranking-table tbody tr .relationship-ranking-table__rank").map { |cell| cell.text.strip }

        expect(response).to have_http_status(:ok)
        expect(ranks).to eq(%w[1 1 3])
        expect(response.body).to include("3 asysty między sobą")
      end

      it "updates meta pills from the filtered ranking results" do
        adam = create(:player, name: "Adam Nowak", nickname: "adam", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Kowalski", nickname: "marek", approval_status: "approved", active: true)
        season = create(:season)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 1), status: "finished")
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        create(:team_player, team: home_team, player: adam)
        create(:team_player, team: home_team, player: marek)
        create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: Time.current)

        get "/relationships", params: {
          tab: "duos",
          minimum_shared_matches: 1,
          player_filter: "Brak"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("0 zawodników")
        expect(response.body).to include("0 połączeń")
        expect(response.body).to include("Brak wyników")
        expect(response.body).not_to include("2 zawodników")
        expect(response.body).not_to include("1 połączenie")
      end

      it "renders the fives tab as an active scalable ranking tab" do
        expect(Synergy::GraphDataQuery).not_to receive(:call)

        get "/relationships", params: { tab: "fives" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("value=\"fives\"")
        expect(response.body).to include("value=\"2\" min=\"1\"")
        expect(response.body).to include("Ranking piątek")
        expect(response.body).to include("Brak wyników")
        expect(response.body).not_to include("relationships-tab--disabled")
      end

      it "renders the Cytoscape graph tab with controls and without private phone data" do
        adam = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        marek = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222", approval_status: "approved", active: true)
        season = create(:season)

        3.times do |index|
          match_day = create(:match_day, season:, played_on: Date.new(2026, 7, index + 1), status: "finished")
          team_setup = create(:team_setup, match_day:)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
          adam_team_player = create(:team_player, team: home_team, player: adam)
          marek_team_player = create(:team_player, team: home_team, player: marek)
          match = create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 0, finished_at: index.days.ago)
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: adam_team_player, assistant_team_player: marek_team_player)
        end

        expect(Synergy::CombinationRankingQuery).not_to receive(:call)

        get "/relationships", params: {
          tab: "graph",
          season_id: season.id,
          minimum_shared_matches: 1,
          limit: 100,
          metric: "goals_assists",
          player_filter: "Adam"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-controller=\"synergy-graph\"")
        expect(response.body).to include("data-synergy-graph-data-value")
        expect(response.body).to include("<turbo-frame")
        expect(response.body).to include("id=\"relationships_results\"")
        expect(response.body).to include("target=\"_top\"")
        expect(response.body).to include("data-controller=\"preserve-scroll\"")
        expect(response.body).to include("data-turbo-frame=\"relationships_results\"")
        expect(response.body).to include("Adam Nowak + Marek Kowalski")
        expect(response.body).to include("Filtry grafu")
        expect(response.body).to include("type=\"number\"")
        expect(response.body).to include("name=\"minimum_shared_matches\"")
        expect(response.body).to include("selected=\"selected\" value=\"100\"")
        expect(response.body).to include("selected=\"selected\" value=\"goals_assists\"")
        expect(response.body).not_to include("Najmocniejsze połączenia")
        expect(response.body).to include("Legenda")
        expect(response.body).to include("Zielona linia = wysoki win rate")
        expect(response.body).not_to include("Szara linia = brak danych")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("phone")
      end

      it "prefills graph filters from the selected player link" do
        adam = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        season = create(:season)

        get "/relationships", params: {
          tab: "graph",
          season_id: season.id,
          player_id: adam.id
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Filtry grafu")
        expect(response.body).to include("name=\"player_id\"")
        expect(response.body).to include("value=\"#{adam.id}\"")
        expect(response.body).to include("value=\"Adam Nowak\"")
        expect(response.body).to include("value=\"1\" min=\"1\"")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("phone")
      end
    end

    context "when no public relationship data exists" do
      it "renders empty states" do
        get "/relationships"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Synergia zawodników")
        expect(response.body).to include("Duety")
        expect(response.body).to include("Graf relacji")
        expect(response.body).to include("Jak czytać synergię?")
        expect(response.body).to include("Brak duetu")
        expect(response.body).to include("Za mało danych")
        expect(response.body).to include("synergy-summary-card__avatar--empty")
        expect(response.body).to include("Brak wyników")
        expect(response.body).to include("Zmień filtr zawodnika albo zmniejsz minimum wspólnych meczów.")
        expect(response.body).not_to include("Publiczni zawodnicy")
        expect(response.body).not_to include("Widoczne połączenia")
      end

      it "renders graph empty state" do
        get "/relationships", params: { tab: "graph" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak relacji")
        expect(response.body).to include("Graf pojawi się, gdy zawodnicy rozegrają wspólne mecze.")
        expect(response.body).not_to include("data-controller=\"synergy-graph\"")
      end
    end
  end
end
