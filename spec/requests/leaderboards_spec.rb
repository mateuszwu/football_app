require "rails_helper"

RSpec.describe "Leaderboards" do
  describe "GET /leaderboards" do
    context "when season ranking data exists" do
      it "renders the public leaderboards page without private phone data" do
        season = create(:season, name: "Summer 2026", status: Season::STATUS_ACTIVE)
        scorer = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true, role_code: "ATT")
        assistant = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222", approval_status: "approved", active: true, role_code: "MID")
        defender = create(:player, name: "Piotr Lis", nickname: "piotr", phone: "+48333333333", approval_status: "approved", active: true, role_code: "DEF")
        pending_player = create(:player, name: "Pending Player", nickname: "pending", phone: "+48444444444", approval_status: "pending", active: true)
        match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 12), status: "finished")
        create(:match_day_player, match_day:, player: scorer)
        create(:match_day_player, match_day:, player: assistant)
        create(:match_day_player, match_day:, player: defender)
        team_setup = create(:team_setup, match_day:)
        home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH)
        match = create(:match, match_day:, home_team:, away_team:, home_score: 3, away_score: 1, started_at: 1.hour.ago, finished_at: 30.minutes.ago)
        create(:team_player, team: home_team, player: scorer)
        create(:team_player, team: home_team, player: assistant)
        create(:team_player, team: away_team, player: defender)
        create(:player_season_stat, season:, player: scorer, elo: 1040, goals: 5, assists: 2, mvp_votes_count: 3, def_votes_count: 0, performance_score: 7.0)
        create(:player_season_stat, season:, player: assistant, elo: 1015, goals: 1, assists: 6, mvp_votes_count: 1, def_votes_count: 1, performance_score: 7.0)
        create(:player_season_stat, season:, player: defender, elo: 1000, goals: 0, assists: 1, mvp_votes_count: 0, def_votes_count: 4, performance_score: 2.0)
        create(:player_season_stat, season:, player: pending_player, elo: 1200, goals: 99)
        create(:player_rating_change, player: scorer, season:, match_day:, match:, elo_delta: 18)

        get leaderboards_path, params: { season_id: season.id, tab: "goals_assists" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Rankingi")
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("Lider ELO")
        expect(response.body).to include("Najlepszy strzelec")
        expect(response.body).to include("Najlepszy asystent")
        expect(response.body).to include("MVP sezonu")
        expect(response.body).to include("Najlepszy DEF")
        expect(response.body).to include("G+A")
        expect(response.body).to include("Bilans")
        expect(response.body).to include("G+A/mecz")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("Marek Kowalski")
        expect(response.body).to include("Piotr Lis")
        expect(response.body).to include(player_path(scorer))
        expect(response.body).to include("ui-icon")
        expect(response.body).to include("<svg")
        expect(response.body.scan("<col ").size).to eq(6)
        expect(response.body).to include("leaderboards-table__col--position")
        expect(response.body).to include("leaderboards-table__col--player")
        expect(response.body).to include("leaderboards-table__col--role")
        expect(response.body).to include("leaderboards-table__col--matches")
        expect(response.body).not_to include("leaderboards-table__col-metric")
        expect(response.body).to include("leaderboard-player-cell")
        expect(response.body).to include(
          "player-identity-pill player-identity-pill--sm player-identity-pill--default"
        )
        expect(response.body).to include("player-identity-pill__icon")
        expect(response.body).to include("player-identity-pill__name")
        expect(response.body).not_to include("leaderboards-player__avatar")
        expect(response.body.scan(/leaderboards-rank__number">(\d+)</).flatten).to include("1", "1", "3")
        expect(response.body).to include("leaderboards-rank--gold")
        expect(response.body).to include("leaderboards-rank--bronze")
        expect(response.body).to include("lucide-medal")
        expect(response.body).not_to include(">Punkty<")
        expect(response.body).not_to include("Pending Player")
        expect(response.body).not_to include("+48111111111")
        expect(response.body).not_to include("+48222222222")
        expect(response.body).not_to include("+48333333333")
        expect(response.body).not_to include("+48444444444")
        expect(response.body).not_to include("phone")

        get leaderboards_path, params: { season_id: season.id, tab: "record" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tabela rankingu: Bilans")
        expect(response.body.scan("<col ").size).to eq(9)
        expect(response.body).to include("Wygrane")
        expect(response.body).to include("Remisy")
        expect(response.body).to include("Porażki")
        expect(response.body).to include("Win rate")
        expect(response.body).not_to include(">Punkty<")

        get leaderboards_path, params: { season_id: season.id, tab: "elo" }

        expect(response).to have_http_status(:ok)
        expect(response.body.scan("<col ").size).to eq(6)
        expect(response.body).to include("Ostatnia zmiana")
        expect(response.body).to include("+18")

        get leaderboards_path, params: { season_id: season.id, tab: "mvp" }

        expect(response).to have_http_status(:ok)
        expect(response.body.scan("<col ").size).to eq(5)
        expect(response.body).to include("Głosy MVP")
      end

      it "renders player identity pills on every ranking tab" do
        season = create(:season, status: Season::STATUS_ACTIVE)
        player = create(
          :player,
          name: "Adam Demo",
          phone: "+48111222333",
          approval_status: "approved",
          active: true,
          profile_icon: "sun",
          profile_color_key: "gold",
          profile_color_hex: "#FACC15"
        )
        create(
          :player_season_stat,
          season:,
          player:,
          elo: 1020,
          goals: 2,
          assists: 2,
          mvp_votes_count: 1,
          def_votes_count: 1
        )

        %w[elo goals assists goals_assists mvp def record].each do |tab|
          get leaderboards_path, params: { season_id: season.id, tab: }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(
            "player-identity-pill player-identity-pill--sm player-identity-pill--default"
          )
          expect(response.body).to include("lucide-sun")
          expect(response.body).to include("Adam Demo")
          expect(response.body).not_to include("+48111222333")
        end
      end

      it "renders no data for MVP and DEF when all vote counts are zero" do
        season = create(:season, name: "Summer 2026", status: Season::STATUS_ACTIVE)
        player = create(:player, name: "Kuba Bratek", nickname: "kuba", approval_status: "approved", active: true)
        create(:player_season_stat, season:, player:, elo: 1000, mvp_votes_count: 0, def_votes_count: 0)

        get leaderboards_path, params: { season_id: season.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("MVP sezonu")
        expect(response.body).to include("Najlepszy DEF")
        season_mvp_card = response.body[/<article class="leaderboards-summary-card">(?:(?!<\/article>).)*MVP sezonu.*?<\/article>/m]
        best_def_card = response.body[/<article class="leaderboards-summary-card">(?:(?!<\/article>).)*Najlepszy DEF.*?<\/article>/m]
        expect(season_mvp_card).to include("Brak danych")
        expect(season_mvp_card).not_to include("Kuba Bratek")
        expect(best_def_card).to include("Brak danych")
        expect(best_def_card).not_to include("Kuba Bratek")

        get leaderboards_path, params: { season_id: season.id, tab: "mvp" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak głosów MVP w tym sezonie.")
        mvp_table_card = response.body[/<section class="leaderboards-table-card">.*?<\/section>/m]
        expect(mvp_table_card).not_to include("Kuba Bratek")

        get leaderboards_path, params: { season_id: season.id, tab: "def" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak głosów DEF w tym sezonie.")
        def_table_card = response.body[/<section class="leaderboards-table-card">.*?<\/section>/m]
        expect(def_table_card).not_to include("Kuba Bratek")
      end
    end

    context "when no seasons exist" do
      it "renders the empty state" do
        get leaderboards_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Brak sezonów")
        expect(response.body).to include("Rankingi pojawią się po utworzeniu pierwszego sezonu.")
      end
    end
  end
end
