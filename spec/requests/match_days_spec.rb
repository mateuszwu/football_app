require "rails_helper"

RSpec.describe "Match days" do
  describe "GET /match_days/:id" do
    it "renders a public completed-day summary without private player data" do
      season = create(:season, name: "Demo Summer 2026")
      match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 19), status: "finished")
      team_setup = create(:team_setup, match_day:)
      orange_team = create(:team, team_setup:, name: "Orange Demo", team_type: Team::TEAM_TYPE_MATCH)
      black_team = create(:team, team_setup:, name: "Black Demo", team_type: Team::TEAM_TYPE_MATCH)
      green_team = create(:team, team_setup:, name: "Green Demo", team_type: Team::TEAM_TYPE_MATCH)
      white_team = create(:team, team_setup:, name: "White Demo", team_type: Team::TEAM_TYPE_MATCH)
      adam = create(:player, name: "Adam Demo", nickname: "adam-demo", phone: "+48111111111", approval_status: "approved")
      bartek = create(:player, name: "Bartek Demo", nickname: "bartek-demo", phone: "+48222222222", approval_status: "approved")
      celina = create(:player, name: "Celina Demo", nickname: "celina-demo", phone: "+48333333333", approval_status: "approved")
      daniel = create(:player, name: "Daniel Demo", nickname: "daniel-demo", phone: "+48444444444", approval_status: "approved")
      ewa = create(:player, name: "Ewa Demo", nickname: "ewa-demo", phone: "+48555555555", approval_status: "approved")
      adam_orange = create(:team_player, team: orange_team, player: adam)
      ewa_orange = create(:team_player, team: orange_team, player: ewa)
      bartek_black = create(:team_player, team: black_team, player: bartek)
      celina_green = create(:team_player, team: green_team, player: celina)
      daniel_white = create(:team_player, team: white_team, player: daniel)
      first_match = create(
        :match,
        match_day:,
        home_team: orange_team,
        away_team: black_team,
        home_score: 2,
        away_score: 1,
        started_at: Time.zone.parse("2026-06-19 17:00:00"),
        finished_at: Time.zone.parse("2026-06-19 17:32:00")
      )
      second_match = create(
        :match,
        match_day:,
        home_team: green_team,
        away_team: white_team,
        home_score: 1,
        away_score: 1,
        started_at: Time.zone.parse("2026-06-19 17:40:00"),
        finished_at: Time.zone.parse("2026-06-19 18:10:00")
      )
      create(
        :match_goal,
        match: first_match,
        scoring_team: orange_team,
        scorer_team_player: adam_orange,
        assistant_team_player: ewa_orange,
        scored_at: Time.zone.parse("2026-06-19 17:02:00"),
        home_score_after: 1,
        away_score_after: 0
      )
      create(
        :match_goal,
        match: first_match,
        scoring_team: orange_team,
        scorer_team_player: bartek_black,
        own_goal: true,
        scored_at: Time.zone.parse("2026-06-19 17:08:00"),
        home_score_after: 2,
        away_score_after: 0
      )
      create(
        :match_goal,
        match: first_match,
        scoring_team: black_team,
        scorer_team_player: bartek_black,
        scored_at: Time.zone.parse("2026-06-19 17:20:00"),
        home_score_after: 2,
        away_score_after: 1
      )
      create(
        :match_goal,
        match: second_match,
        scoring_team: green_team,
        scorer_team_player: celina_green,
        scored_at: Time.zone.parse("2026-06-19 17:45:00"),
        home_score_after: 1,
        away_score_after: 0
      )
      create(
        :match_goal,
        match: second_match,
        scoring_team: white_team,
        scorer_team_player: daniel_white,
        scored_at: Time.zone.parse("2026-06-19 18:00:00"),
        home_score_after: 1,
        away_score_after: 1
      )
      voter_match_day_player = create(:match_day_player, match_day:, player: bartek)
      vote_token = create(:match_day_vote_token, match_day_player: voter_match_day_player)
      MatchDayVote.create!(match_day_vote_token: vote_token, mvp_player: adam, def_player: celina)

      get "/match_days/#{match_day.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dzień grania · 19.06.2026")
      expect(response.body).to include("Demo Summer 2026")
      expect(response.body).to include("2 mecze")
      expect(response.body).to include("5 zawodników")
      expect(response.body).to include("Mecze dnia")
      expect(response.body).to include("Mecz #1")
      expect(response.body).to include("17:00 - 17:32")
      expect(response.body).to include("Orange Demo")
      expect(response.body).to include("Black Demo")
      expect(response.body).to include("2 : 1")
      expect(response.body).to include("Wygrana Orange Demo")
      expect(response.body).to include("Bartek Demo, sam.")
      expect(response.body).to include("Liderzy dnia")
      expect(response.body).to include("Najlepszy strzelec")
      expect(response.body).to include("Najlepszy asystent")
      expect(response.body).to include("MVP")
      expect(response.body).to include("DEF")
      expect(response.body).to include("Zawodnicy tego dnia")
      expect(response.body).to include("Zobacz mecz")
      expect(response.body).to include("/matches/#{first_match.id}")
      expect(response.body).not_to include("+48111111111")
      expect(response.body).not_to include("+48222222222")
      expect(response.body).not_to include("phone")
    end

    it "renders empty states when there are no finished matches" do
      match_day = create(:match_day, played_on: Date.new(2026, 6, 19), status: "setup")

      get "/match_days/#{match_day.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Brak zakończonych meczów dla tego dnia.")
      expect(response.body).to include("Brak danych o liderach dnia.")
      expect(response.body).to include("Brak zawodników do wyświetlenia.")
    end
  end
end
