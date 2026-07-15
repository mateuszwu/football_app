require "rails_helper"

RSpec.describe "Statistics" do
  describe "GET /statistics" do
    context "when public season timeline data exists" do
      it "renders season statistics without private phone data" do
        season = create(:season, name: "Summer 2026")
        adam = create(:player, name: "Adam Demo", phone: "+48111111111", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", phone: "+48222222222", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, status: "finished", played_on: Date.new(2026, 7, 1))
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Zieloni")
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Czarni")
        home_team_player = create(:team_player, team: home_team, player: adam)
        away_team_player = create(:team_player, team: away_team, player: bartek)
        start_time = Time.zone.local(2026, 7, 1, 18, 0, 0)
        match = create(:match, match_day:, home_team:, away_team:, started_at: start_time, finished_at: start_time + 5.minutes, home_score: 5, away_score: 0)

        [ 30, 60, 120, 180, 300 ].each do |seconds|
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: home_team_player, scored_at: start_time + seconds.seconds)
        end
        create(:match_goal, match:, scoring_team: away_team, scorer_team_player: away_team_player, scored_at: start_time + 40.seconds, undone_at: Time.current)

        get "/statistics", params: { season_id: season.id, tab: "tempo" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Statystyki i ciekawostki")
        expect(response.body).to include("Tempo meczu")
        tabs = Nokogiri::HTML(response.body).at_css(".stats-tabs")
        expect(tabs["role"]).to eq("tablist")
        expect(tabs.css(".leaderboards-tab[role='tab']").size).to eq(6)
        expect(response.body).to include("Najszybszy gol")
        expect(response.body).to include("00:30")
        expect(response.body).to include("Rozkład czasu meczów")
        expect(response.body).to include("data-controller=\"stats-chart\"")
        expect(response.body).to include("Zawodnicy clutch")
        expect(response.body).to include("statistics-quick-row")
        expect(response.body).to include("statistics-quick-value")
        expect(response.body).to include("statistics-match-link")
        expect(response.body).to include(match_path(match))
        expect(response.body).not_to include("Najczęstszy scenariusz")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("phone")

        get "/statistics", params: { season_id: season.id, tab: "first_goal" }

        expect(response).to have_http_status(:ok)
        first_goal_table = Nokogiri::HTML(response.body).at_css("table.stats-first-goal-table")
        expect(first_goal_table).not_to be_nil
        expect(first_goal_table.css(".player-identity-pill").size).to eq(1)
        expect(first_goal_table.css(".player-identity-pill__icon").size).to eq(1)
        expect(first_goal_table.css(".stats-player-link")).to be_empty
        expect(response.body).to include("stats-first-goal-table-wrap")

        get "/statistics", params: { season_id: season.id, tab: "records" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Najwięcej goli w meczu")
        expect(response.body).to include("Adam Demo")
        expect(response.body).to include("5 goli")
        expect(response.body).to include("Największa dominacja")
        expect(response.body).to include("+5 / 5:0")
        expect(response.body).to include(match_path(match))
      end
    end

    context "when no season exists" do
      it "renders an empty state" do
        get "/statistics"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Statystyki i ciekawostki")
        expect(response.body).to include("Brak sezonów")
      end
    end
  end
end
