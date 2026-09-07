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
        tempo_table = Nokogiri::HTML(response.body).at_css("table.stats-records-table")
        expect(tempo_table.css("thead th a.leaderboards-sort-link").size).to eq(3)
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
        expect(first_goal_table.css("thead th").map { |header| header.text.strip }).to include("Mecze rozegrane")
        expect(first_goal_table.css("thead th a.leaderboards-sort-link").size).to eq(5)
        expect(response.body).to include("stats-first-goal-table-wrap")

        get "/statistics", params: { season_id: season.id, tab: "score_states" }

        expect(response).to have_http_status(:ok)
        score_states_table = Nokogiri::HTML(response.body).at_css("table.stats-records-table")
        expect(score_states_table.css("thead th a.leaderboards-sort-link").size).to eq(5)

        get "/statistics", params: { season_id: season.id, tab: "records" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Najwięcej goli w meczu")
        expect(response.body).to include("Adam Demo")
        expect(response.body).to include("5 goli")
        expect(response.body).to include("Największa dominacja")
        expect(response.body).to include("+5 / 5:0")
        expect(response.body).to include(match_path(match))
        records_table = Nokogiri::HTML(response.body).at_css("table.stats-records-table")
        expect(records_table.css("thead th a.leaderboards-sort-link").size).to eq(3)

        get "/statistics", params: { season_id: season.id, tab: "clutch" }

        expect(response).to have_http_status(:ok)
        clutch_table = Nokogiri::HTML(response.body).at_css("table.stats-records-table")
        expect(clutch_table).not_to be_nil
        expect(clutch_table.css(".player-identity-pill").size).to eq(1)
        expect(clutch_table.css(".player-identity-pill__icon").size).to eq(1)
        expect(clutch_table.css(".stats-player-link")).to be_empty
        expect(clutch_table.css("thead th a.leaderboards-sort-link").size).to eq(7)
      end

      it "links a randomly selected comeback example to its match" do
        season = create(:season, name: "Summer 2026")
        home_player = create(:player, name: "Home Demo", approval_status: "approved", active: true)
        away_player = create(:player, name: "Away Demo", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, status: "finished", played_on: Date.new(2026, 7, 1))
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Zieloni")
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Czarni")
        home_team_player = create(:team_player, team: home_team, player: home_player)
        away_team_player = create(:team_player, team: away_team, player: away_player)
        start_time = Time.zone.local(2026, 7, 1, 18, 0, 0)
        match = create(:match, match_day:, home_team:, away_team:, started_at: start_time, finished_at: start_time + 6.minutes, home_score: 5, away_score: 1)
        create(:match_goal, match:, scoring_team: away_team, scorer_team_player: away_team_player, scored_at: start_time + 30.seconds)
        [ 60, 90, 120, 150, 180 ].each do |seconds|
          create(:match_goal, match:, scoring_team: home_team, scorer_team_player: home_team_player, scored_at: start_time + seconds.seconds)
        end

        get "/statistics", params: { season_id: season.id, tab: "comebacks" }

        expect(response).to have_http_status(:ok)
        table = Nokogiri::HTML(response.body).at_css("table.stats-records-table")
        comeback_row = table.css("tbody tr").find { |row| row.at_css("td").text.strip == "0:1" }
        example_link = comeback_row.at_css("td:nth-child(5) a.statistics-match-link")
        expect(example_link["href"]).to eq(match_path(match))
        expect(example_link.text.strip).to eq("2026-07-01 · ##{match.id}")
        expect(table.css("thead th a.leaderboards-sort-link").size).to eq(5)
      end

      it "sorts first-goal rows by the selected column" do
        season = create(:season, name: "Summer 2026")
        adam = create(:player, name: "Adam Demo", approval_status: "approved", active: true)
        bartek = create(:player, name: "Bartek Demo", approval_status: "approved", active: true)

        create_match_with_first_goal = lambda do |player, played_on|
          day = create(:match_day, season:, status: "finished", played_on:)
          team_setup = create(:team_setup, match_day: day)
          home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Zieloni")
          away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, name: "Czarni")
          player_team_player = create(:team_player, team: home_team, player:)
          opponent_team_player = create(:team_player, team: away_team)
          start_time = Time.zone.local(2026, 7, played_on.day, 18, 0, 0)
          match = create(:match, match_day: day, home_team:, away_team:, started_at: start_time, finished_at: start_time + 5.minutes, home_score: 5, away_score: 0)

          [ 30, 60, 120, 180, 300 ].each do |seconds|
            create(:match_goal, match:, scoring_team: home_team, scorer_team_player: player_team_player, scored_at: start_time + seconds.seconds)
          end
          create(:match_goal, match:, scoring_team: away_team, scorer_team_player: opponent_team_player, scored_at: start_time + 40.seconds, undone_at: Time.current)
        end

        create_match_with_first_goal.call(adam, Date.new(2026, 7, 1))
        create_match_with_first_goal.call(bartek, Date.new(2026, 7, 2))

        get "/statistics", params: { season_id: season.id, tab: "first_goal", sort: "first_goals", sort_direction: "asc" }

        expect(response).to have_http_status(:ok)
        table = Nokogiri::HTML(response.body).at_css("table.stats-first-goal-table")
        player_names = table.css("tbody .player-identity-pill__name").map { |player| player.text.strip }
        first_goals_header = table.at_css("thead th:nth-child(2)")

        expect(player_names).to eq([ "Adam Demo", "Bartek Demo" ])
        expect(first_goals_header["aria-sort"]).to eq("ascending")
        expect(first_goals_header.at_css("a")["href"]).to include("sort_direction=desc")
        expect(table.css("thead th a.leaderboards-sort-link").size).to eq(5)
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
