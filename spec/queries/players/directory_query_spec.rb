require "rails_helper"

RSpec.describe Players::DirectoryQuery do
  describe ".call" do
    it "returns approved active players with season-filtered roster stats" do
      season = create(:season, name: "Summer 2026")
      other_season = create(:season, name: "Spring 2026")
      player = create(:player, name: "Adam Nowak", nickname: "adam", role_code: "DEF", approval_status: "approved", active: true, elo: 1010)
      teammate = create(:player, name: "Marek Test", nickname: "marek", role_code: "MID", approval_status: "approved", active: true)
      opponent = create(:player, name: "Piotr Rival", nickname: "piotr", approval_status: "approved", active: true)
      create(:player, name: "Pending Player", approval_status: "pending", active: true)
      create(:player, name: "Inactive Player", approval_status: "approved", active: false)
      create(:player_season_stat, player:, season:, elo: 1042, goals: 9, assists: 4)

      match_day = create(:match_day, season:, played_on: Date.new(2026, 7, 1), status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
      player_team_player = create(:team_player, player:, team: home_team)
      teammate_team_player = create(:team_player, player: teammate, team: home_team)
      create(:team_player, player: opponent, team: away_team)
      match = create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 0, status: Match::STATUS_FINISHED, finished_at: Time.zone.parse("2026-07-01 20:00:00"))
      create(:match_goal, match:, scoring_team: home_team, scorer_team_player: player_team_player, assistant_team_player: teammate_team_player)

      other_match_day = create(:match_day, season: other_season, played_on: Date.new(2026, 4, 1), status: "finished")
      other_team_setup = create(:team_setup, match_day: other_match_day)
      other_home_team = create(:team, team_setup: other_team_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
      other_away_team = create(:team, team_setup: other_team_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
      create(:team_player, player:, team: other_home_team)
      create(:match, match_day: other_match_day, home_team: other_home_team, away_team: other_away_team, home_score: 0, away_score: 1, status: Match::STATUS_FINISHED, finished_at: Time.zone.parse("2026-04-01 20:00:00"))

      result = described_class.call(params: { season_id: season.id, role: "DEF", q: "adam" })

      expect(result.selected_season).to eq(season)
      expect(result.total_players_count).to eq(3)
      expect(result.filtered_players_count).to eq(1)
      expect(result.players.map(&:player)).to eq([ player ])
      expect(result.players.first.matches_count).to eq(1)
      expect(result.players.first.wins).to eq(1)
      expect(result.players.first.draws).to eq(0)
      expect(result.players.first.losses).to eq(0)
      expect(result.players.first.win_rate).to eq(100)
      expect(result.players.first.goals).to eq(1)
      expect(result.players.first.assists).to eq(0)
      expect(result.players.first.season_stat.elo).to eq(1042)
      expect(result.players.first.last_played_on).to eq(Date.new(2026, 7, 1))
    end

    it "falls back to score-derived result when team result is missing" do
      season = create(:season)
      player = create(:player, approval_status: "approved", active: true)
      opponent = create(:player, approval_status: "approved", active: true)
      match_day = create(:match_day, season:, status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: nil)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: nil)
      create(:team_player, player:, team: away_team)
      create(:team_player, player: opponent, team: home_team)
      create(:match, match_day:, home_team:, away_team:, home_score: 1, away_score: 1, finished_at: Time.zone.parse("2026-06-05 20:00:00"))

      result = described_class.call(params: { season_id: season.id })

      card = result.players.find { |player_card| player_card.player == player }
      expect(card.draws).to eq(1)
      expect(card.win_rate).to eq(0)
    end
  end
end
