require "rails_helper"

RSpec.describe Players::OpponentRecordsQuery do
  describe ".call" do
    it "returns per-opponent results for a selected season" do
      season = create(:season, name: "Summer 2026")
      other_season = create(:season, name: "Spring 2026", starts_on: Date.new(2026, 3, 1))
      tracked_player = create(:player, name: "Tracked")
      opponent_one = create(:player, name: "Adam")
      opponent_two = create(:player, name: "Marek")

      first_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5), status: "finished")
      first_setup = create(:team_setup, match_day: first_match_day)
      first_home = create(:team, team_setup: first_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
      first_away = create(:team, team_setup: first_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
      create(:team_player, team: first_home, player: tracked_player)
      create(:team_player, team: first_away, player: opponent_one)
      create(:match, match_day: first_match_day, home_team: first_home, away_team: first_away, home_score: 1, away_score: 0, finished_at: Time.zone.parse("2026-06-05 20:00:00"))

      second_match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 12), status: "finished")
      second_setup = create(:team_setup, match_day: second_match_day)
      second_home = create(:team, team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_DRAW)
      second_away = create(:team, team_setup: second_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_DRAW)
      create(:team_player, team: second_home, player: tracked_player)
      create(:team_player, team: second_away, player: opponent_one)
      create(:team_player, team: second_away, player: opponent_two)
      create(:match, match_day: second_match_day, home_team: second_home, away_team: second_away, home_score: 1, away_score: 1, finished_at: Time.zone.parse("2026-06-12 20:00:00"))

      other_match_day = create(:match_day, season: other_season, played_on: Date.new(2026, 4, 5), status: "finished")
      other_setup = create(:team_setup, match_day: other_match_day)
      other_home = create(:team, team_setup: other_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
      other_away = create(:team, team_setup: other_setup, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
      create(:team_player, team: other_home, player: tracked_player)
      create(:team_player, team: other_away, player: opponent_two)
      create(:match, match_day: other_match_day, home_team: other_home, away_team: other_away, home_score: 0, away_score: 2, finished_at: Time.zone.parse("2026-04-05 20:00:00"))

      result = described_class.call(player: tracked_player, season:)

      expect(result.map { |record| [ record.opponent.name, record.matches_count, record.wins, record.draws, record.losses ] }).to eq(
        [
          [ "Adam", 2, 1, 1, 0 ],
          [ "Marek", 1, 0, 1, 0 ]
        ]
      )
    end

    it "returns records when the player is on the away team without a season filter" do
      season = create(:season, name: "Summer 2026")
      tracked_player = create(:player, name: "Tracked")
      opponent = create(:player, name: "Adam")
      match_day = create(:match_day, season:, played_on: Date.new(2026, 6, 5), status: "finished")
      team_setup = create(:team_setup, match_day:)
      home_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_WIN)
      away_team = create(:team, team_setup:, team_type: Team::TEAM_TYPE_MATCH, result: Team::RESULT_LOSS)
      create(:team_player, team: home_team, player: opponent)
      create(:team_player, team: away_team, player: tracked_player)
      create(:match, match_day:, home_team:, away_team:, home_score: 2, away_score: 0, finished_at: Time.zone.parse("2026-06-05 20:00:00"))

      result = described_class.call(player: tracked_player)

      expect(result.map { |record| [ record.opponent.name, record.matches_count, record.wins, record.draws, record.losses ] }).to eq(
        [
          [ "Adam", 1, 0, 0, 1 ]
        ]
      )
    end

    it "returns nil for defensive team lookups when the player is absent" do
      player = build_stubbed(:player)
      other_player = build_stubbed(:player)
      home_team = instance_double(Team, players: [ other_player ])
      away_team = instance_double(Team, players: [])
      match = instance_double(Match, home_team:, away_team:)
      query = described_class.new(player:, season: nil)

      player_team = query.send(:team_for, match:, player:)
      opponent_team = query.send(:opponent_team_for, match:, player_team: nil)

      expect(player_team).to be_nil
      expect(opponent_team).to be_nil
    end
  end
end
