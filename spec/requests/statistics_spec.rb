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
        expect(response.body).to include("Najszybszy gol")
        expect(response.body).to include("00:30")
        expect(response.body).to include("Rozkład czasu meczów")
        expect(response.body).to include("data-controller=\"stats-chart\"")
        expect(response.body).to include("Zawodnicy clutch")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("phone")
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
