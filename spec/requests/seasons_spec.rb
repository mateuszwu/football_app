require "rails_helper"

RSpec.describe "Seasons" do
  describe "GET /seasons/:id" do
    context "when the season has match days and players" do
      it "renders a public season hub without full rankings or private phone data" do
        spring = create(:season, name: "Spring 2026", starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 5, 31))
        season = create(:season, name: "Summer 2026", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 8, 31))
        scorer = create(:player, name: "Adam Nowak", nickname: "adam", phone: "+48111111111", approval_status: "approved", active: true)
        assister = create(:player, name: "Marek Kowalski", nickname: "marek", phone: "+48222222222", approval_status: "approved", active: true)
        def_player = create(:player, name: "Piotr Lis", nickname: "piotr", phone: "+48333333333", approval_status: "approved", active: true)
        create(:match_day, season: season, played_on: Date.new(2026, 6, 2), status: "finished")
        latest_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 12), status: "ready")
        first_match_day = create(:match_day, season: season, played_on: Date.new(2026, 6, 5), status: "finished")
        create(:match_day_player, match_day: first_match_day, player: scorer)
        create(:match_day_player, match_day: latest_match_day, player: scorer)
        assister_match_day_player = create(:match_day_player, match_day: latest_match_day, player: assister)
        create(:match_day_player, match_day: latest_match_day, player: def_player)
        create(:player_season_stat, season: season, player: scorer, elo: 1042, goals: 5, assists: 1, mvp_votes_count: 3, def_votes_count: 0)
        create(:player_season_stat, season: season, player: assister, elo: 1030, goals: 2, assists: 6, mvp_votes_count: 1, def_votes_count: 1)
        create(:player_season_stat, season: season, player: def_player, elo: 1018, goals: 5, assists: 2, mvp_votes_count: 0, def_votes_count: 4)
        create(:player_season_stat, season: spring, player: scorer, elo: 990, goals: 1, assists: 1, mvp_votes_count: 0, def_votes_count: 0)
        first_setup = create(:team_setup, match_day: first_match_day)
        first_home = create(:team, team_setup: first_setup, name: "Orange Team", team_type: Team::TEAM_TYPE_MATCH)
        first_away = create(:team, team_setup: first_setup, name: "Black Team", team_type: Team::TEAM_TYPE_MATCH)
        first_scorer = create(:team_player, team: first_home, player: scorer)
        first_assister = create(:team_player, team: first_home, player: assister)
        first_defender = create(:team_player, team: first_away, player: def_player)
        first_match = create(
          :match,
          match_day: first_match_day,
          home_team: first_home,
          away_team: first_away,
          started_at: Time.zone.parse("2026-06-05 19:00:00"),
          finished_at: Time.zone.parse("2026-06-05 19:30:00"),
          status: Match::STATUS_FINISHED
        )
        create(:match_goal, match: first_match, scoring_team: first_home, scorer_team_player: first_scorer, assistant_team_player: first_assister, scored_at: Time.zone.parse("2026-06-05 19:05:00"))
        create(:match_goal, match: first_match, scoring_team: first_home, scorer_team_player: first_defender, own_goal: true, scored_at: Time.zone.parse("2026-06-05 19:10:00"))
        create(:match_goal, match: first_match, scoring_team: first_away, scorer_team_player: first_defender, scored_at: Time.zone.parse("2026-06-05 19:15:00"), undone_at: Time.zone.parse("2026-06-05 19:16:00"))
        latest_setup = create(:team_setup, match_day: latest_match_day)
        latest_home = create(:team, team_setup: latest_setup, name: "Green Team", team_type: Team::TEAM_TYPE_MATCH)
        latest_away = create(:team, team_setup: latest_setup, name: "White Team", team_type: Team::TEAM_TYPE_MATCH)
        latest_scorer = create(:team_player, team: latest_home, player: scorer)
        create(:team_player, team: latest_away, player: assister)
        latest_match = create(
          :match,
          match_day: latest_match_day,
          home_team: latest_home,
          away_team: latest_away,
          started_at: Time.zone.parse("2026-06-12 20:00:00"),
          finished_at: Time.zone.parse("2026-06-12 20:40:00"),
          status: Match::STATUS_FINISHED
        )
        create(:match_goal, match: latest_match, scoring_team: latest_home, scorer_team_player: latest_scorer, scored_at: Time.zone.parse("2026-06-12 20:08:00"))
        vote_token = create(:match_day_vote_token, match_day_player: assister_match_day_player)
        MatchDayVote.create!(match_day_vote_token: vote_token, mvp_player: scorer, def_player: def_player)

        get "/seasons/#{season.id}", params: { season_id: season.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Summer 2026")
        expect(response.body).to include("2026-06-01")
        expect(response.body).to include("2026-08-31")
        expect(response.body).to include("SEZON")
        expect(response.body).to include("Zobacz rankingi")
        expect(response.body).to include("Dni grania")
        expect(response.body).to include("Przegląd wszystkich rozegranych dni grania w tym sezonie.")
        expect(response.body).to include("od najnowszych")
        expect(response.body).to include("od najstarszych")
        expect(response.body).to include("Mecze")
        expect(response.body).to include("Zawodnicy")
        expect(response.body).to include("Gole")
        expect(response.body).to include("Czas gry")
        expect(response.body).to include("Śr. zaw./dzień")
        expect(response.body).to include("Sezon w skrócie")
        expect(response.body).to include("Pierwszy dzień grania")
        expect(response.body).to include("05.06.2026")
        expect(response.body).to include("Ostatni dzień grania")
        expect(response.body).to include("12.06.2026")
        expect(response.body).to include("Łączna liczba meczów")
        expect(response.body).to include("Łączna liczba goli")
        expect(response.body).to include("Łączna liczba asyst")
        expect(response.body).to include("Samobóje")
        expect(response.body).to include("Średni czas meczu")
        expect(response.body).to include("35 min")
        expect(response.body).to include("Green Team")
        expect(response.body).to include("White Team")
        expect(response.body).to include("Orange Team")
        expect(response.body).to include("Black Team")
        expect(response.body).to include("CZE")
        expect(response.body).to include("Zobacz dzień")
        expect(response.body).to include("/match_days/#{latest_match_day.id}")
        expect(response.body).to include("Najaktywniejsi zawodnicy")
        expect(response.body).to include("Adam Nowak")
        expect(response.body).to include("Piotr Lis")
        expect(response.body).not_to include("Co dalej?")
        expect(response.body).not_to include("Rankingi sezonu")
        expect(response.body).not_to include("Statystyki sezonu")
        expect(response.body).not_to include("Zawodnicy sezonu")
        expect(response.body).not_to include("Zakres sezonu (planowany)")
        expect(response.body).not_to include("na podstawie rozegranych dni grania")
        expect(response.body).not_to include("Filtruj")
        expect(response.body).not_to include("Ranking ELO")
        expect(response.body).not_to include("Top strzelcy")
        expect(response.body).not_to include("Top asysty")
        expect(response.body).not_to include("1042 Elo")
        expect(response.body).not_to include("adam")
        expect(response.body).not_to include("marek")
        expect(response.body).to include("12")
        expect(response.body).to include("Gotowy")
        expect(response.body).to include("5")
        expect(response.body).to include("Zakończony")
        expect(response.body.index("Green Team")).to be < response.body.index("Orange Team")
        expect(response.body).not_to include("Spring 2026")
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
        expect(response.body).to include("Brak dni grania")
        expect(response.body).to include("Ten sezon nie ma jeszcze dodanych dni grania.")
        expect(response.body).to include("Sezon w skrócie")
        expect(response.body).to include("—")
        expect(response.body).not_to include("Ranking ELO")
      end
    end
  end
end
