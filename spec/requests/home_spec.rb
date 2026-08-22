require "rails_helper"

RSpec.describe "Home page" do
  describe "GET /" do
    context "when public visitor opens the app" do
      it "renders the public dashboard and navigation" do
        path = root_path

        get path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Football App")
        expect(response.body).to include("Weekendowe granie")
        expect(response.body).to include("branding/neon_green_football_emblem")
        expect(response.body).to include('alt="Football App"')
        expect(response.body).to include("sidebar-brand__logo")
        expect(response.body).to include("mobile-app-header")
        expect(response.body).to include('<body class="theme-dark public-layout" data-controller="mobile-nav">')
        expect(response.body).to include('data-action="mobile-nav#open"')
        expect(response.body).to include('data-mobile-nav-target="drawer"')
        expect(response.body).to include("mobile-nav-drawer__links")
        expect(response.body).to include("mobile-nav-link")

        mobile_header = response.body[/<header class="mobile-app-header">.*?<\/header>/m]
        expect(mobile_header).not_to include("mobile-nav-overlay")
        expect(mobile_header).not_to include("mobile-nav-drawer")

        expect(response.body).to include("favicon")
        expect(response.body).to include("favicon-32x32")
        expect(response.body).to include("favicon-16x16")
        expect(response.body).to include("android-chrome-192x192")
        expect(response.body).to include("android-chrome-512x512")
        expect(response.body).to include("apple-touch-icon")
        expect(response.body).to include("Przegląd")
        expect(response.body).to include("lucide-layout-dashboard")
        expect(response.body).to include("lucide-trophy")
        expect(response.body).to include("lucide-network")
        expect(response.body).to include("lucide-users")
        expect(response.body).to include("lucide-user-plus")
        expect(response.body).to include("lucide-log-in")
        expect(response.body).to include("Aktywny sezon")
        expect(response.body).not_to include("Najblizszy / aktywny Match Day")
        expect(response.body).not_to include('id="nearest_match_day"')
        expect(response.body).to include("Bilans dnia")
        expect(response.body).not_to include("Ostatni rozegrany mecz")
        expect(response.body).to include("Top ELO")
        expect(response.body).to include("Top strzelcy")
        expect(response.body).to include("Top asysty")
        expect(response.body).to include("MVP / DEF")
        expect(response.body).to include("Synergia")
        expect(response.body).to include("Rankingi")
        expect(response.body).to include("Synergia")
        expect(response.body).to include("Zawodnicy")
        expect(response.body).not_to include('href="/players/new"')
        expect(response.body).to include("Dołącz")
        expect(response.body).to include("Zaloguj")
        expect(response.body).not_to include("Wyloguj")
        expect(response.body).not_to include("site-nav__link--active\">Admin")
        expect(response.body.scan("dashboard-tile__watermark").size).to eq(8)
        expect(response.body).to include('id="join_game"')
        expect(response.body).to include("join-tile__icon")
        expect(response.body).to include("Zapisy są tymczasowo wstrzymane.")
        expect(response.body).to include("dashboard-button--disabled")
        expect(response.body).to include("site-nav__link--disabled")
        expect(response.body).to include("<svg")
        expect(response.body).not_to include('class="tile-icon')
        expect(response.body).not_to include("day-balance-icon")
        expect(response.body).not_to include(">CUP<")
        expect(response.body).not_to include(">KIT<")
        expect(response.body).not_to include(">PLY<")
        expect(response.body).not_to include(">SEZ<")
        expect(response.body).not_to include('id="leaderboards"')
        expect(response.body).not_to include('id="players"')

        join_tile = response.body[/<article class="dashboard-tile dashboard-tile--span-4 dashboard-tile--join" id="join_game">.*?<\/article>/m]
        expect(join_tile).to include("Dołącz do gry")
        expect(join_tile).to include("join-tile__icon")
        expect(join_tile).not_to include("href=")
        expect(join_tile).not_to include("dashboard-tile__number")
        expect(join_tile).not_to include("dashboard-tile__watermark")
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

    context "when admin opens the app" do
      it "renders authorized admin navigation items" do
        begin
          original_admin_password = ENV["FOOTBALL_APP_ADMIN_PASSWORD"]
          ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = "secret-password"

          post "/admin/session", params: { password: "secret-password" }
          get root_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Dni grania")
          expect(response.body).to include("Sezony")
          expect(response.body).to include("Admin")
          expect(response.body).to include("Wyloguj")
          expect(response.body).to include("mobile-nav-link--button")
        ensure
          if original_admin_password.nil?
            ENV.delete("FOOTBALL_APP_ADMIN_PASSWORD")
          else
            ENV["FOOTBALL_APP_ADMIN_PASSWORD"] = original_admin_password
          end
        end
      end
    end

    context "when public approved players exist" do
      it "renders player summary without private phone data or duplicated player list" do
        create(
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
        expect(response.body).to include("Zawodnicy")
        expect(response.body).to include("1 zatwierdzonych profili")
        expect(response.body).not_to include("Adam Nowak")
        expect(response.body).not_to include("Pending Player")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include('id="players"')
      end
    end

    context "when an active season exists" do
      it "renders a link to the season stats page" do
        season = create(:season, name: "Summer 2026", status: Season::STATUS_ACTIVE)

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include(season_path(season))
      end

      it "renders the latest finished match day date as the season end" do
        season = create(
          :season,
          name: "Summer 2026",
          status: Season::STATUS_ACTIVE,
          ends_on: Date.new(2026, 8, 31)
        )
        create(:match_day, season:, played_on: Date.new(2026, 6, 5), status: "finished")
        create(:match_day, season:, played_on: Date.new(2026, 6, 12), status: "finished")
        create(:match_day, season:, played_on: Date.new(2026, 6, 19), status: "ready")

        get root_path

        expect(response).to have_http_status(:ok)
        active_season_tile = response.body[/<article class="dashboard-tile dashboard-tile--span-4" id="active_season">.*?<\/article>/m]
        expect(active_season_tile).to include("12.06.2026")
        expect(active_season_tile).not_to include("19.06.2026")
        expect(active_season_tile).not_to include("31.08.2026")
      end
    end

    context "when dashboard statistics exist" do
      it "renders populated public dashboard tiles without private phone data" do
        season = create(:season, name: "Summer 2026", status: Season::STATUS_ACTIVE)
        scorer = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true, role_code: "ATT")
        assistant = create(:player, name: "Jan Kowal", nickname: "jan", phone: "+48222222222", approval_status: "approved", active: true, role_code: "MID")
        defender = create(:player, name: "Marek Lis", nickname: "marek", phone: "+48333333333", approval_status: "approved", active: true, role_code: "DEF")
        match_day = create(:match_day, season:, played_on: Date.current + 1.day, status: "finished")
        [ scorer, assistant, defender ].each do |player|
          create(:match_day_player, match_day:, player:)
        end
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, name: "Orange Team", team_setup:, team_type: Team::TEAM_TYPE_MATCH, score: 2)
        away_team = create(:team, name: "Black Team", team_setup:, team_type: Team::TEAM_TYPE_MATCH, score: 1)
        match = create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 1, started_at: 1.hour.ago, finished_at: 30.minutes.ago)
        scorer_team_player = create(:team_player, team: home_team, player: scorer)
        assistant_team_player = create(:team_player, team: home_team, player: assistant)
        create(:match_goal, match:, scoring_team: home_team, scorer_team_player:, assistant_team_player:)

        second_match_day = create(:match_day, season:, played_on: Date.current - 2.days, status: "finished")
        [ scorer, assistant, defender ].each do |player|
          create(:match_day_player, match_day: second_match_day, player:)
        end
        second_setup = create(:team_setup, match_day: second_match_day)
        second_home_team = create(:team, name: "Green Team", team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH, score: 1)
        second_away_team = create(:team, name: "Blue Team", team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH, score: 0)
        create(:team_player, team: second_home_team, player: scorer)
        create(:team_player, team: second_home_team, player: assistant)
        create(:team_player, team: second_away_team, player: defender)
        create(:match, match_day: second_match_day, home_team: second_home_team, away_team: second_away_team, home_score: 1, away_score: 0, started_at: 2.days.ago, finished_at: 2.days.ago + 30.minutes)

        third_match_day = create(:match_day, season:, played_on: Date.current - 1.day, status: "finished")
        [ scorer, assistant, defender ].each do |player|
          create(:match_day_player, match_day: third_match_day, player:)
        end
        third_setup = create(:team_setup, match_day: third_match_day)
        third_home_team = create(:team, name: "White Team", team_setup: third_setup, team_type: Team::TEAM_TYPE_MATCH, score: 0)
        third_away_team = create(:team, name: "Red Team", team_setup: third_setup, team_type: Team::TEAM_TYPE_MATCH, score: 1)
        create(:team_player, team: third_home_team, player: defender)
        create(:team_player, team: third_away_team, player: scorer)
        create(:team_player, team: third_away_team, player: assistant)
        create(:match, match_day: third_match_day, home_team: third_home_team, away_team: third_away_team, home_score: 0, away_score: 1, started_at: 1.day.ago, finished_at: 1.day.ago + 30.minutes)
        create(:player_season_stat, season:, player: scorer, elo: 1040, goals: 2, assists: 1, mvp_votes_count: 3)
        create(:player_season_stat, season:, player: assistant, elo: 1010, goals: 1, assists: 4, def_votes_count: 2)
        create(:player_season_stat, season:, player: defender, elo: 1000, goals: 2)

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("Orange Team")
        expect(response.body).to include("Black Team")
        expect(response.body).to include("W meczach")
        day_balance_tile = response.body[/<article class="dashboard-tile dashboard-tile--span-6 dashboard-tile--tall" id="last_match">.*?<\/article>/m]
        expect(day_balance_tile).to include("Bilans dnia")
        expect(day_balance_tile).not_to include("teamy")
        expect(response.body).to include("Zobacz wszystkie mecze dnia")
        expect(day_balance_tile).to include(match_day_path(match_day))
        expect(day_balance_tile).not_to include(match_path(match))
        expect(response.body).to include("1040")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("Jan Kowal")
        expect(response.body).to include("Marek Lis")
        expect(response.body).to include("0 oddanych głosów")
        expect(response.body).not_to include("otwartych tokenów")
        top_scorers_tile = response.body[/<article class="dashboard-tile dashboard-tile--span-3 dashboard-tile--ranking" id="top_scorers">.*?<\/article>/m]
        expect(top_scorers_tile.scan(/ranking-preview__rank">(\d+)</).flatten).to eq(%w[1 1 3])
        expect(top_scorers_tile).to include(
          "player-identity-pill player-identity-pill--xs player-identity-pill--compact"
        )
        expect(top_scorers_tile).not_to include("ranking-preview__avatar")
        expect(top_scorers_tile).not_to include("Napastnik")
        expect(top_scorers_tile).not_to include("Pomocnik")
        expect(top_scorers_tile).not_to include("Obrońca")
        expect(day_balance_tile).to include(
          "player-identity-pill player-identity-pill--xs player-identity-pill--compact"
        )
        expect(response.body).to include("dashboard-best-duo__players")
        expect(response.body).not_to include("dashboard-best-duo__avatars")
        expect(response.body).to include("Najlepszy duet")
        expect(response.body).to include("3 wspólne mecze")
        expect(response.body).to include("3W · 0R · 0P")
        expect(response.body).to include("100% wygranych")
        expect(response.body).to match(/1 gol\s+·\s+1 asysta/)
        expect(response.body).to include("Zobacz synergię")
        expect(response.body).not_to include(">Silne<")
        expect(response.body).not_to include(">Bez relacji<")
        expect(response.body).not_to include(">Wspolne duety<")
        expect(response.body).not_to include(">Stałe duety<")
        expect(response.body).not_to include(">Nowi bez historii<")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("+48333333333")
      end

      it "renders no data for MVP and DEF when no player has votes" do
        season = create(:season, name: "Summer 2026", status: Season::STATUS_ACTIVE)
        player = create(:player, name: "Kuba Bratek", nickname: "kuba", approval_status: "approved", active: true)
        match_day = create(:match_day, season:, played_on: Date.current, status: "finished")
        match_day_player = create(:match_day_player, match_day:, player:)
        create(:match_day_vote_token, match_day_player:)
        create(:player_season_stat, season:, player:, elo: 1000, mvp_votes_count: 0, def_votes_count: 0)

        get root_path

        expect(response).to have_http_status(:ok)
        mvp_def_tile = response.body[/<article class="dashboard-tile dashboard-tile--span-5 dashboard-tile--wide" id="mvp_def">.*?<\/article>/m]
        expect(mvp_def_tile).to include("MVP sezonu")
        expect(mvp_def_tile).to include("Najlepszy DEF")
        expect(mvp_def_tile.scan("Brak danych").size).to eq(2)
        expect(mvp_def_tile).not_to include("Kuba Bratek")
        expect(mvp_def_tile).not_to include("0 głosów")
      end
    end
  end
end
